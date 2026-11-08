# =============================================================================
# Lesson 15: Health data types and data quality
# Goal:     build a small, reusable quality report (completeness, sentinel codes,
#           plausibility, duplicates, consistency) and apply it to simulated tables.
# Inputs:   data-sim/out/ehr_A_patients.csv, data-sim/out/ehr_A_diagnoses.csv,
#           data-sim/out/patients_messy.csv
# Outputs:  printed tables; output/L15_missingness.png
# Packages: readr, dplyr, ggplot2
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
# 1. The five families of health data (a small reference table)
# -----------------------------------------------------------------------------
health_data_types <- tibble(
  family = c("Structured", "Free text", "Images", "Signals", "Administrative"),
  example = c("Diagnosis codes, lab results, vital signs",
              "Clinical notes, discharge letters",
              "X-ray, retinal photograph, histology slide",
              "ECG trace, continuous glucose monitor, wearable data",
              "Admissions, billing and claims records"),
  usual_r_object = c("data frame / tibble", "character vector", "array or file path",
                     "time series (numeric vector + time)", "data frame / tibble"),
  typical_quality_risk = c("Missing values, wrong units, inconsistent codes",
                           "Negation, abbreviations, copy-paste text",
                           "Different devices and settings",
                           "Gaps, noise, device differences",
                           "Coded for payment, not for science")
)
print(health_data_types)

# -----------------------------------------------------------------------------
# 2. Read three tables of different quality
# -----------------------------------------------------------------------------
patients  <- read_csv("data-sim/out/ehr_A_patients.csv", show_col_types = FALSE)
diagnoses <- read_csv("data-sim/out/ehr_A_diagnoses.csv", show_col_types = FALSE)
messy     <- read_csv("data-sim/out/patients_messy.csv", show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 3. Check 1 - completeness: one row per column
# -----------------------------------------------------------------------------
quality_report <- function(df) {
  tibble(
    column     = names(df),
    type       = vapply(df, function(x) class(x)[1], character(1)),
    n_missing  = vapply(df, function(x) sum(is.na(x)), integer(1)),
    pct_missing = round(100 * n_missing / nrow(df), 1),
    n_distinct = vapply(df, function(x) n_distinct(x), integer(1))
  )
}

cat("\n--- Quality report: clean patient table ---\n")
print(quality_report(patients))
cat("\n--- Quality report: messy patient table ---\n")
print(quality_report(messy))
# Note: glucose shows 0% missing, yet the column hides missing values (see check 2).

# -----------------------------------------------------------------------------
# 4. Check 2 - sentinel codes: missing values disguised as numbers
# -----------------------------------------------------------------------------
sentinel_codes <- c(-9999, -999, -99, 9999)
sentinel_counts <- messy %>%
  summarise(across(where(is.numeric), ~ sum(.x %in% sentinel_codes)))
cat("\n--- Sentinel codes per numeric column ---\n")
print(sentinel_counts)

# -----------------------------------------------------------------------------
# 5. Check 3 - plausibility: values outside a range decided in advance
# -----------------------------------------------------------------------------
count_outside <- function(x, lower, upper) sum(x < lower | x > upper, na.rm = TRUE)

cat("\nAge outside 18-95 (clean table): ", count_outside(patients$age, 18, 95), "\n")
cat("Weight outside 30-150 (messy table, all rows): ",
    count_outside(messy$weight, 30, 150), "\n")
cat("Weight outside 30-150, by unit:\n")
print(messy %>%
        group_by(weight_unit) %>%
        summarise(n = n(), outside_range = count_outside(weight, 30, 150)))
# Many pound values are flagged, but many others look plausible: a range check
# alone cannot tell kilograms from pounds. You need the unit column.

# -----------------------------------------------------------------------------
# 6. Check 4 - duplicates and keys
# -----------------------------------------------------------------------------
cat("\nDuplicated patient ids: ", sum(duplicated(patients$patient_id)), "\n")
cat("Duplicated patient + phenotype pairs in diagnoses: ",
    sum(duplicated(diagnoses[, c("patient_id", "phenotype_id")])), "\n")

# -----------------------------------------------------------------------------
# 7. Check 5 - consistency between tables and over time
# -----------------------------------------------------------------------------
orphans <- sum(!diagnoses$patient_id %in% patients$patient_id)
cat("Diagnoses whose patient is not in the patient table: ", orphans, "\n")
cat("Diagnosis dates range from ", format(min(diagnoses$date)),
    " to ", format(max(diagnoses$date)), "\n", sep = "")

# -----------------------------------------------------------------------------
# 8. Make missingness visible (after recoding the sentinel to NA)
# -----------------------------------------------------------------------------
messy_recoded <- messy %>% mutate(glucose_mmol_l = na_if(glucose_mmol_l, -999))
missing_plot_data <- quality_report(messy_recoded)

p_missing <- ggplot(missing_plot_data, aes(x = reorder(column, pct_missing), y = pct_missing)) +
  geom_col(fill = cesgen_blue[["mid"]]) +
  coord_flip() +
  labs(title = "Missing values after recoding the sentinel",
       x = NULL, y = "Missing (%)", caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L15_missingness.png", p_missing, width = 6, height = 3.5, dpi = 150)

# -----------------------------------------------------------------------------
# 9. Sanity checks
# -----------------------------------------------------------------------------
stopifnot(nrow(patients) == 1000,
          !anyDuplicated(patients$patient_id),
          orphans == 0,
          sum(sentinel_counts) > 0,
          file.exists("output/L15_missingness.png"))
cat("\nL15 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Write a function flag_sentinels(df) that returns, for every numeric column,
#    how many values equal -999 and what percentage of the column that is.
# 2. Using quality_report() and your function, write one sentence per column of
#    `messy` saying what is wrong with it (or "nothing found").
# 3. Decide which of the five checks (completeness, sentinel, plausibility,
#    duplicates, consistency) would NOT have caught the kilogram/pound mix.
# Expected: glucose has no NA but about 6% of values are -999; weight has no NA
# and no sentinel but mixes two units; only the unit column resolves it.
# Worked solution: lessons/solutions/L15_solution.R
# =============================================================================
