# =============================================================================
# Lesson 17: Load and explore a clinical database - tables, keys and joins
# Goal:     read the two-site simulated EHR, check keys, join tables safely and
#           explore the result with summaries and two plots.
# Inputs:   data-sim/out/ehr_A_patients.csv, ehr_A_diagnoses.csv,
#           ehr_B_patients.csv, ehr_B_diagnoses.csv, phenotype_map.csv
# Outputs:  printed tables; output/L17_age_by_site.png, output/L17_prevalence_by_site.png
# Packages: readr, dplyr, ggplot2 (dplyr 1.1.0 or later for the `relationship` argument)
# Data:     Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(readr)
library(dplyr)
library(ggplot2)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Read both sites and the phenotype dictionary
# -----------------------------------------------------------------------------
read_site <- function(site) {
  list(
    patients  = read_csv(sprintf("data-sim/out/ehr_%s_patients.csv", site), show_col_types = FALSE),
    diagnoses = read_csv(sprintf("data-sim/out/ehr_%s_diagnoses.csv", site), show_col_types = FALSE)
  )
}
site_a <- read_site("A")
site_b <- read_site("B")
phenotype_map <- read_csv("data-sim/out/phenotype_map.csv", show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 2. Look before you join: shape and columns of every table
# -----------------------------------------------------------------------------
cat("Site A patients:  ", nrow(site_a$patients), "rows x", ncol(site_a$patients), "columns\n")
cat("Site A diagnoses: ", nrow(site_a$diagnoses), "rows x", ncol(site_a$diagnoses), "columns\n")
glimpse(site_a$patients)
glimpse(site_a$diagnoses)
glimpse(phenotype_map)

# -----------------------------------------------------------------------------
# 3. Keys: one row per patient in `patients`; many rows per patient in `diagnoses`
# -----------------------------------------------------------------------------
stopifnot(!anyDuplicated(site_a$patients$patient_id),
          !anyDuplicated(site_b$patients$patient_id))

# Foreign key check: every diagnosis must belong to a known patient
orphans_a <- anti_join(site_a$diagnoses, site_a$patients, by = "patient_id")
cat("Diagnoses without a patient (site A):", nrow(orphans_a), "\n")

# -----------------------------------------------------------------------------
# 4. The four joins you need, shown on a toy example
# -----------------------------------------------------------------------------
toy_patients <- tibble(patient_id = c("P1", "P2", "P3"), age = c(34, 58, 71))
toy_dx <- tibble(patient_id = c("P1", "P1", "P3", "P9"),
                 code = c("E11", "I10", "I10", "F32"))
cat("\nleft_join (keep every patient):\n");       print(left_join(toy_patients, toy_dx, by = "patient_id"))
cat("\ninner_join (only matches):\n");            print(inner_join(toy_patients, toy_dx, by = "patient_id"))
cat("\nanti_join (patients without diagnoses):\n"); print(anti_join(toy_patients, toy_dx, by = "patient_id"))
cat("\nanti_join (diagnoses without a patient):\n"); print(anti_join(toy_dx, toy_patients, by = "patient_id"))

# A duplicated key on both sides multiplies rows: always compare row counts
key_a <- tibble(id = c(1, 2, 2), x = c("a", "b", "c"))
key_b <- tibble(id = c(2, 2), y = c("p", "q"))
multiplied <- suppressWarnings(left_join(key_a, key_b, by = "id"))
cat("\nRows before:", nrow(key_a), " rows after a many-to-many join:", nrow(multiplied), "\n")

# -----------------------------------------------------------------------------
# 5. Join the real tables and verify the row count did not change
# -----------------------------------------------------------------------------
dx_a_full <- site_a$diagnoses %>%
  left_join(site_a$patients, by = "patient_id", relationship = "many-to-one") %>%
  left_join(phenotype_map %>% select(phenotype_id, phenotype),
            by = "phenotype_id", relationship = "many-to-one")
stopifnot(nrow(dx_a_full) == nrow(site_a$diagnoses))
print(head(dx_a_full, 5))

# -----------------------------------------------------------------------------
# 6. Stack the two sites (patient ids start with the site letter, so they are unique)
# -----------------------------------------------------------------------------
patients_all  <- bind_rows(site_a$patients, site_b$patients)
diagnoses_all <- bind_rows(site_a$diagnoses, site_b$diagnoses) %>%
  left_join(patients_all %>% select(patient_id, site), by = "patient_id")
stopifnot(!anyDuplicated(patients_all$patient_id),
          nrow(diagnoses_all) == nrow(site_a$diagnoses) + nrow(site_b$diagnoses),
          !any(is.na(diagnoses_all$site)))

# -----------------------------------------------------------------------------
# 7. Explore: who is in the database?
# -----------------------------------------------------------------------------
cat("\nPatients, mean age and share with an adverse drug event, by site:\n")
print(patients_all %>%
        group_by(site) %>%
        summarise(n = n(), mean_age = round(mean(age), 1),
                  pct_female = round(100 * mean(sex == "F"), 1),
                  pct_ade = round(100 * mean(ade), 1)))

cat("\nDiagnoses per patient, by site (patients with none count as 0):\n")
dx_per_patient <- patients_all %>%
  left_join(count(diagnoses_all, patient_id, name = "n_dx"), by = "patient_id") %>%
  mutate(n_dx = coalesce(n_dx, 0L))
print(dx_per_patient %>% group_by(site) %>%
        summarise(median = median(n_dx), max = max(n_dx), none = sum(n_dx == 0)))

cat("\nShare of diagnosis rows by ICD version and site:\n")
print(diagnoses_all %>% count(site, icd_version) %>%
        group_by(site) %>% mutate(pct = round(100 * n / sum(n), 1)))

# -----------------------------------------------------------------------------
# 8. Prevalence of each phenotype by site (patients with it / patients in the site)
# -----------------------------------------------------------------------------
n_by_site <- patients_all %>% count(site, name = "n_site")
prevalence <- diagnoses_all %>%
  distinct(site, patient_id, phenotype_id) %>%
  count(site, phenotype_id, name = "n_patients") %>%
  left_join(n_by_site, by = "site") %>%
  mutate(prevalence = n_patients / n_site) %>%
  left_join(phenotype_map %>% select(phenotype_id, phenotype), by = "phenotype_id")

cat("\nFive most frequent phenotypes in site A:\n")
print(prevalence %>% filter(site == "A") %>% arrange(desc(prevalence)) %>% head(5))

# -----------------------------------------------------------------------------
# 9. Two plots
# -----------------------------------------------------------------------------
p_age <- ggplot(patients_all, aes(x = age)) +
  geom_histogram(binwidth = 5, fill = cesgen_blue[["mid"]], colour = "white") +
  facet_wrap(~ site, ncol = 1, labeller = label_both) +
  labs(title = "Age distribution by site", x = "Age (years)", y = "Patients",
       caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L17_age_by_site.png", p_age, width = 6, height = 5, dpi = 150)

top_phenotypes <- prevalence %>%
  group_by(phenotype) %>%
  summarise(mean_prevalence = mean(prevalence), .groups = "drop") %>%
  arrange(desc(mean_prevalence)) %>%
  head(15) %>%
  pull(phenotype)

p_prev <- prevalence %>%
  filter(phenotype %in% top_phenotypes) %>%
  ggplot(aes(x = reorder(phenotype, prevalence), y = prevalence, fill = site)) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_fill_manual(values = c(A = cesgen_blue[["mid"]], B = cesgen_blue[["accent"]])) +
  labs(title = "Fifteen most frequent phenotypes", x = NULL,
       y = "Share of patients", caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L17_prevalence_by_site.png", p_prev, width = 7, height = 5, dpi = 150)

stopifnot(file.exists("output/L17_age_by_site.png"),
          file.exists("output/L17_prevalence_by_site.png"))
cat("\nL17 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. For each site, compute the share of patients with an adverse drug event
#    (ade == 1) among patients WITH hypertension (phenotype PH03) and WITHOUT it.
#    Hint: build a logical column with patient_id %in% diagnoses_all$patient_id[...].
# 2. Count, by site, how many diagnosis rows use ICD-9 and how many ICD-10 codes.
# 3. Draw a bar chart of the result of task 1 and save it in output/.
# Expected: in both sites the ADE share is usually higher with hypertension than
# without (the simulation plants this association, so random variation can blur it);
# site B is older than site A.
# Worked solution: lessons/solutions/L17_solution.R
# =============================================================================
