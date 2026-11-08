# Solution for lesson 17 (run from the repository root).
library(readr)
library(dplyr)
library(ggplot2)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

patients_all <- bind_rows(read_csv("data-sim/out/ehr_A_patients.csv", show_col_types = FALSE),
                          read_csv("data-sim/out/ehr_B_patients.csv", show_col_types = FALSE))
diagnoses_all <- bind_rows(read_csv("data-sim/out/ehr_A_diagnoses.csv", show_col_types = FALSE),
                           read_csv("data-sim/out/ehr_B_diagnoses.csv", show_col_types = FALSE))

# 1. ADE share with and without hypertension (PH03), by site
hypertension_ids <- diagnoses_all$patient_id[diagnoses_all$phenotype_id == "PH03"]
ade_by_hypertension <- patients_all %>%
  mutate(hypertension = ifelse(patient_id %in% hypertension_ids, "With hypertension", "Without hypertension")) %>%
  group_by(site, hypertension) %>%
  summarise(n = n(), pct_ade = round(100 * mean(ade), 1), .groups = "drop")
print(ade_by_hypertension)

# 2. ICD-9 and ICD-10 rows by site
diagnoses_with_site <- diagnoses_all %>%
  left_join(patients_all %>% select(patient_id, site), by = "patient_id")
print(count(diagnoses_with_site, site, icd_version))

# 3. Bar chart
p <- ggplot(ade_by_hypertension, aes(x = hypertension, y = pct_ade, fill = site)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c(A = cesgen_blue[["mid"]], B = cesgen_blue[["accent"]])) +
  labs(title = "Adverse drug events with and without hypertension",
       x = NULL, y = "Patients with an ADE (%)", caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L17_solution_ade_by_hypertension.png", p, width = 6, height = 4, dpi = 150)

stopifnot(nrow(ade_by_hypertension) == 4, file.exists("output/L17_solution_ade_by_hypertension.png"))
