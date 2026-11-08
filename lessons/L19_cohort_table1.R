# =============================================================================
# Lesson 19: Cohorts and the descriptive table ("Table 1")
# Goal:     define a cohort with explicit, computable criteria, count who is lost
#           at each step, and summarise the cohort in a "Table 1" built with dplyr
#           and tidyr (no extra packages).
# Inputs:   data-sim/out/ehr_A_*.csv, ehr_B_*.csv, phenotype_map.csv
# Outputs:  printed tables; output/L19_attrition.csv, output/L19_table1.csv
# Packages: readr, dplyr, tidyr, knitr
# Data:     Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(knitr)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Read and stack both sites
# -----------------------------------------------------------------------------
patients_all <- bind_rows(read_csv("data-sim/out/ehr_A_patients.csv", show_col_types = FALSE),
                          read_csv("data-sim/out/ehr_B_patients.csv", show_col_types = FALSE))
diagnoses_all <- bind_rows(read_csv("data-sim/out/ehr_A_diagnoses.csv", show_col_types = FALSE),
                           read_csv("data-sim/out/ehr_B_diagnoses.csv", show_col_types = FALSE))

# -----------------------------------------------------------------------------
# 2. A computable phenotype is a written rule. Here, the rule for type 2 diabetes:
#    at least one diagnosis row in phenotype group PH01 (ICD-10 E11, or its local
#    placeholder code in the ICD-9 rows). Two variants show that the rule matters.
# -----------------------------------------------------------------------------
has_phenotype <- function(patient_ids, diagnoses, phenotype_id, versions = c(9, 10)) {
  hit_ids <- diagnoses$patient_id[diagnoses$phenotype_id == phenotype_id &
                                    diagnoses$icd_version %in% versions]
  patient_ids %in% hit_ids
}

patients_all <- patients_all %>%
  mutate(
    t2d_any     = has_phenotype(patient_id, diagnoses_all, "PH01"),
    t2d_icd10   = has_phenotype(patient_id, diagnoses_all, "PH01", versions = 10),
    t1d         = has_phenotype(patient_id, diagnoses_all, "PH02"),
    hypertension = has_phenotype(patient_id, diagnoses_all, "PH03"),
    depression   = has_phenotype(patient_id, diagnoses_all, "PH05"),
    any_diagnosis = patient_id %in% diagnoses_all$patient_id
  )

cat("Type 2 diabetes, either coding system: ", sum(patients_all$t2d_any), "\n")
cat("Type 2 diabetes, ICD-10 rows only:     ", sum(patients_all$t2d_icd10), "\n")
cat("-> the stricter rule misses", sum(patients_all$t2d_any) - sum(patients_all$t2d_icd10),
    "patients recorded only with the older coding system.\n")

# -----------------------------------------------------------------------------
# 3. Cohort definition (write it down before you compute anything)
#    Inclusion: age 40 or older; at least one diagnosis record
#    Exclusion: type 1 diabetes recorded
#    Exposure groups: type 2 diabetes (either coding system) versus none
# -----------------------------------------------------------------------------
step_0 <- patients_all
step_1 <- step_0 %>% filter(age >= 40)
step_2 <- step_1 %>% filter(any_diagnosis)
step_3 <- step_2 %>% filter(!t1d)

attrition <- tibble(
  step = c("All patients, sites A and B",
           "Age 40 or older",
           "At least one diagnosis record",
           "Without type 1 diabetes (final cohort)"),
  n = c(nrow(step_0), nrow(step_1), nrow(step_2), nrow(step_3))
) %>%
  mutate(lost_at_step = lag(n) - n)
cat("\nAttrition table:\n")
print(kable(attrition))
write_csv(attrition, "output/L19_attrition.csv")

cohort <- step_3 %>%
  mutate(group = ifelse(t2d_any, "Type 2 diabetes", "No type 2 diabetes"))

# -----------------------------------------------------------------------------
# 4. Table 1: one column per group (plus "All"), one row per characteristic
# -----------------------------------------------------------------------------
fmt_continuous <- function(x) sprintf("%.1f (%.1f)", mean(x), sd(x))
fmt_binary <- function(x) sprintf("%d (%.1f%%)", sum(x), 100 * mean(x))

describe_group <- function(d) {
  tibble(
    characteristic = c("Patients, n",
                       "Age in years, mean (SD)",
                       "Female, n (%)",
                       "Site B, n (%)",
                       "Hypertension, n (%)",
                       "Depressive episode, n (%)",
                       "Adverse drug event, n (%)"),
    value = c(as.character(nrow(d)),
              fmt_continuous(d$age),
              fmt_binary(d$sex == "F"),
              fmt_binary(d$site == "B"),
              fmt_binary(d$hypertension),
              fmt_binary(d$depression),
              fmt_binary(d$ade == 1))
  )
}

by_group <- cohort %>%
  group_by(group) %>%
  group_modify(~ describe_group(.x)) %>%
  ungroup()

all_column <- describe_group(cohort) %>% mutate(group = "All")

table1 <- bind_rows(all_column, by_group) %>%
  pivot_wider(names_from = group, values_from = value) %>%
  select(characteristic, All, everything())

cat("\nTable 1 (simulated data for teaching purposes):\n")
print(kable(table1))
write_csv(table1, "output/L19_table1.csv")

# -----------------------------------------------------------------------------
# 5. A first look at the exposure-outcome link (crude, not adjusted)
# -----------------------------------------------------------------------------
crude_model <- glm(ade ~ t2d_any, data = cohort, family = binomial())
print(tidy_or(crude_model, "t2d_anyTRUE"))
# This is a crude odds ratio. Lesson 21 adjusts for age and sex and tests 40 phenotypes.

# -----------------------------------------------------------------------------
# 6. Sanity checks
# -----------------------------------------------------------------------------
stopifnot(all(diff(attrition$n) <= 0),
          sum(as.integer(unlist(table1[1, c("No type 2 diabetes", "Type 2 diabetes")]))) == nrow(cohort),
          all(cohort$age >= 40),
          !any(cohort$t1d))
cat("\nL19 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Change the age criterion to 50 and add an exclusion for chronic kidney
#    disease (phenotype PH09). Produce the new attrition table.
# 2. Rebuild Table 1 with the new cohort and one extra row: "Obesity, n (%)"
#    (phenotype PH16).
# 3. Compare the stricter (ICD-10 only) and the broader definition of type 2
#    diabetes in the new cohort: how many patients change group?
# Expected: every step of the attrition table is equal to or smaller than the
# previous one; the group sizes in Table 1 add up to the cohort size; the
# stricter definition moves some patients into the "No type 2 diabetes" group.
# Worked solution: lessons/solutions/L19_solution.R
# =============================================================================
