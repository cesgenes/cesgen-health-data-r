# ------------------------------------------------------------------------------
# Lesson 28: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/patients_areas_sim.csv, data-sim/out/areas_sim_attributes.csv
# Outputs:  none (results printed)
# Packages: dplyr, readr
# Run from the repository root (RStudio project). Simulated data for teaching purposes.
# ------------------------------------------------------------------------------

library(dplyr)
library(readr)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
ensure_extra_4_data()

patients <- as.data.frame(readr::read_csv("data-sim/out/patients_areas_sim.csv",
                                          show_col_types = FALSE))

# The suppression function from the lesson
suppress_small_counts <- function(df, count_col, threshold = 5) {
  stopifnot(count_col %in% names(df), threshold >= 2)
  n <- df[[count_col]]
  small <- !is.na(n) & n > 0 & n < threshold
  df$suppressed <- small
  df$count_shown <- ifelse(small, paste0("<", threshold), as.character(n))
  df
}

# Task 1: area totals with thresholds 5 and 10
area_totals <- patients %>% dplyr::count(area_id, name = "n_cases")
hidden_5 <- sum(suppress_small_counts(area_totals, "n_cases", 5)$suppressed)
hidden_10 <- sum(suppress_small_counts(area_totals, "n_cases", 10)$suppressed)
cat("Areas hidden with threshold 5:", hidden_5, " with threshold 10:", hidden_10, "\n")
stopifnot(hidden_10 >= hidden_5)

# Task 2: k for area + sex + broad age group
patients$age_broad <- ifelse(patients$age_group %in% c("0-17", "18-39"), "0-39", "40+")
k_fine <- k_anonymity(patients, c("area_id", "sex", "age_group"))$k
k_broad <- k_anonymity(patients, c("area_id", "sex", "age_broad"))$k
cat("k with four age groups:", k_fine, " k with two age groups:", k_broad, "\n")
stopifnot(k_broad >= k_fine)
if (k_broad < 5) {
  cat("k is still below 5: suppress the small cells or release only area totals.\n")
}

# Task 3: a release check that explains itself
check_release <- function(df, quasi_identifiers, k_min = 5) {
  k <- k_anonymity(df, quasi_identifiers)$k
  if (k >= k_min) "OK" else paste0("Not safe to release: k = ", k, " (minimum ", k_min, ")")
}
print(check_release(patients, "area_id"))
print(check_release(patients, c("area_id", "sex", "age_group", "admission_month")))
stopifnot(check_release(patients, c("area_id", "sex", "age_group", "admission_month")) != "OK")
