# =============================================================================
# Lesson 4 - Worked solution of the exercise
# Goal:     Build a tibble by hand, set its types and count a group in a real table.
# Inputs:   data-sim/out/patients_clean.csv (simulated patients)
# Outputs:  printed tables only
# Packages: dplyr, readr
# Run from the repository root.
# Simulated data for teaching purposes. The four patients are invented.
# =============================================================================

library(dplyr)
library(readr)
source("R/helpers_general.R")
ensure_sim_data()

# 1. Four invented patients, five columns -------------------------------------------------
my_patients <- tibble(
  patient_id = c("M01", "M02", "M03", "M04"),
  age = c(29L, 63L, 77L, 51L),
  sex = c("F", "F", "M", "M"),
  diabetic = c(FALSE, TRUE, TRUE, FALSE),
  visit_date = as.Date(c("2026-02-02", "2026-02-02", "2026-02-03", "2026-02-04"))
)

# 2. Sex as a factor, then check the types -------------------------------------------------------
my_patients$sex <- factor(my_patients$sex, levels = c("F", "M"))
glimpse(my_patients)

# 3. Count the patients aged 65 or more in the simulated file ------------------------------------------------
patients <- read_csv("data-sim/out/patients_clean.csv", show_col_types = FALSE)
patients$age_band <- cut(patients$age, breaks = c(17, 39, 64, Inf),
                         labels = c("18-39", "40-64", "65+"))
band_counts <- table(patients$age_band)
print(band_counts)

# 4. Sanity checks ------------------------------------------------------------------------------------------------
stopifnot(
  is.factor(my_patients$sex),
  is.logical(my_patients$diabetic),
  inherits(my_patients$visit_date, "Date"),
  band_counts[["65+"]] == sum(patients$age >= 65),
  sum(band_counts) == nrow(patients)
)
cat("Solution for lesson 4 ran correctly.\n")
