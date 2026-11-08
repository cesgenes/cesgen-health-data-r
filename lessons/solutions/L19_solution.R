# Solution for lesson 19 (run from the repository root).
library(readr)
library(dplyr)
library(tidyr)
library(knitr)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

patients_all <- bind_rows(read_csv("data-sim/out/ehr_A_patients.csv", show_col_types = FALSE),
                          read_csv("data-sim/out/ehr_B_patients.csv", show_col_types = FALSE))
diagnoses_all <- bind_rows(read_csv("data-sim/out/ehr_A_diagnoses.csv", show_col_types = FALSE),
                           read_csv("data-sim/out/ehr_B_diagnoses.csv", show_col_types = FALSE))

has_phenotype <- function(patient_ids, diagnoses, phenotype_id, versions = c(9, 10)) {
  hit_ids <- diagnoses$patient_id[diagnoses$phenotype_id == phenotype_id &
                                    diagnoses$icd_version %in% versions]
  patient_ids %in% hit_ids
}

patients_all <- patients_all %>%
  mutate(t2d_any = has_phenotype(patient_id, diagnoses_all, "PH01"),
         t2d_icd10 = has_phenotype(patient_id, diagnoses_all, "PH01", versions = 10),
         t1d = has_phenotype(patient_id, diagnoses_all, "PH02"),
         ckd = has_phenotype(patient_id, diagnoses_all, "PH09"),
         hypertension = has_phenotype(patient_id, diagnoses_all, "PH03"),
         depression = has_phenotype(patient_id, diagnoses_all, "PH05"),
         obesity = has_phenotype(patient_id, diagnoses_all, "PH16"),
         any_diagnosis = patient_id %in% diagnoses_all$patient_id)

# 1. New criteria: age 50 or older, at least one record, no type 1 diabetes, no CKD
s0 <- patients_all
s1 <- s0 %>% filter(age >= 50)
s2 <- s1 %>% filter(any_diagnosis)
s3 <- s2 %>% filter(!t1d)
s4 <- s3 %>% filter(!ckd)
attrition <- tibble(step = c("All patients", "Age 50 or older", "At least one diagnosis record",
                             "Without type 1 diabetes", "Without chronic kidney disease"),
                    n = c(nrow(s0), nrow(s1), nrow(s2), nrow(s3), nrow(s4)))
print(kable(attrition))

# 2. Table 1 with an extra row for obesity
cohort <- s4 %>% mutate(group = ifelse(t2d_any, "Type 2 diabetes", "No type 2 diabetes"))
fmt_continuous <- function(x) sprintf("%.1f (%.1f)", mean(x), sd(x))
fmt_binary <- function(x) sprintf("%d (%.1f%%)", sum(x), 100 * mean(x))
describe_group <- function(d) {
  tibble(characteristic = c("Patients, n", "Age in years, mean (SD)", "Female, n (%)",
                            "Hypertension, n (%)", "Depressive episode, n (%)",
                            "Obesity, n (%)", "Adverse drug event, n (%)"),
         value = c(as.character(nrow(d)), fmt_continuous(d$age), fmt_binary(d$sex == "F"),
                   fmt_binary(d$hypertension), fmt_binary(d$depression),
                   fmt_binary(d$obesity), fmt_binary(d$ade == 1)))
}
table1 <- bind_rows(describe_group(cohort) %>% mutate(group = "All"),
                    cohort %>% group_by(group) %>% group_modify(~ describe_group(.x)) %>% ungroup()) %>%
  pivot_wider(names_from = group, values_from = value) %>%
  select(characteristic, All, everything())
print(kable(table1))

# 3. How many patients change group under the stricter definition?
n_changed <- sum(cohort$t2d_any & !cohort$t2d_icd10)
cat("Patients who leave the diabetes group under the ICD-10-only rule:", n_changed, "\n")

stopifnot(all(diff(attrition$n) <= 0), n_changed >= 0,
          sum(as.integer(unlist(table1[1, c("No type 2 diabetes", "Type 2 diabetes")]))) == nrow(cohort))
