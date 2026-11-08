# ------------------------------------------------------------------------------
# Lesson 28: Joining social and clinical data by area without compromising privacy
# Goal:     measure how identifiable records are at different aggregation levels
#           (k-anonymity-style check), write a small-number suppression function and
#           build an area table that is safe to share.
# Inputs:   data-sim/out/patients_areas_sim.csv (created by data-sim/extra_4.R),
#           data-sim/out/areas_sim_attributes.csv
# Outputs:  output/L28_area_table_shareable.csv
# Packages: dplyr, tidyr, readr
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. No real patients.
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
ensure_extra_4_data()
dir.create("output", showWarnings = FALSE)

patients <- as.data.frame(readr::read_csv("data-sim/out/patients_areas_sim.csv",
                                          show_col_types = FALSE))
attrs <- as.data.frame(readr::read_csv("data-sim/out/areas_sim_attributes.csv",
                                       show_col_types = FALSE))
# NOTE: 'attrs' holds the true, unsuppressed counts. Treat it as the secure copy.
stopifnot(nrow(patients) == sum(attrs$cases), !anyDuplicated(attrs$area_id))

# 1. Which columns could identify someone? -------------------------------------------
# The helper flags column NAMES that look like identifiers (a hint, not a guarantee).
mock_table <- data.frame(postcode = "XX1 1XX", dob = "2000-01-01", sex = "F")
print(flag_identifier_columns(mock_table))
print(names(patients))                        # always read the real column list yourself
# patient_id is an internal identifier: it is removed before anything is shared.
# area, sex, age group and month are quasi-identifiers: combined, they can single out a person.

# 2. How identifiable are the records at each level of detail? -----------------------
# k is the size of the smallest group sharing the same values (k = 1: someone is unique).
qi_levels <- list(
  "area" = c("area_id"),
  "area + sex" = c("area_id", "sex"),
  "area + sex + age group" = c("area_id", "sex", "age_group"),
  "area + sex + age group + month" = c("area_id", "sex", "age_group", "admission_month")
)
k_table <- do.call(rbind, lapply(names(qi_levels), function(nm) {
  res <- k_anonymity(patients, qi_levels[[nm]])
  data.frame(quasi_identifiers = nm, k = as.integer(res$k),
             n_groups = res$n_groups, n_unique = res$n_unique, stringsAsFactors = FALSE)
}))
print(k_table)
stopifnot(all(diff(k_table$k) <= 0))          # more detail can only lower k

# A small helper: does a release meet a minimum group size?
meets_k <- function(df, quasi_identifiers, k_min = 5) {
  k_anonymity(df, quasi_identifiers)$k >= k_min
}
cat("Area level meets k >= 5:", meets_k(patients, "area_id"), "\n")
cat("Area + sex + age + month meets k >= 5:",
    meets_k(patients, c("area_id", "sex", "age_group", "admission_month")), "\n")

# Generalising is the alternative to suppressing: merge categories to make groups larger.
patients$age_broad <- ifelse(patients$age_group %in% c("0-17", "18-39"), "0-39", "40+")
k_broad <- k_anonymity(patients, c("area_id", "sex", "age_broad"))
cat("k for area + sex + broad age:", k_broad$k, "\n")

# 3. A small-number suppression function ----------------------------------------------
# Counts from 1 to (threshold - 1) are hidden. Real thresholds and rules for zeros are
# set by the data owner's disclosure-control policy: check them before releasing anything.
suppress_small_counts <- function(df, count_col, threshold = 5) {
  stopifnot(count_col %in% names(df), threshold >= 2)
  n <- df[[count_col]]
  small <- !is.na(n) & n > 0 & n < threshold
  df$suppressed <- small
  df$count_shown <- ifelse(small, paste0("<", threshold), as.character(n))
  df
}

cells <- patients %>%
  dplyr::count(area_id, sex, age_group, name = "n_cases") %>%
  tidyr::complete(area_id, sex, age_group, fill = list(n_cases = 0L))
cells_s <- suppress_small_counts(cells, "n_cases", threshold = 5)

area_totals <- patients %>% dplyr::count(area_id, name = "n_cases")
area_totals_s <- suppress_small_counts(area_totals, "n_cases", threshold = 5)

cat("Share of cells suppressed (area x sex x age group):", round(mean(cells_s$suppressed), 2), "\n")
cat("Share of areas suppressed (area totals):", round(mean(area_totals_s$suppressed), 2), "\n")
stopifnot(all(cells_s$count_shown[cells_s$suppressed] == "<5"),
          mean(cells_s$suppressed) >= mean(area_totals_s$suppressed))

# 4. Traps: totals and rates can undo the suppression --------------------------------
toy <- data.frame(group = c("F", "M"), n = c(3, 52))
toy_s <- suppress_small_counts(toy, "n", 5)
print(toy_s)
published_total <- sum(toy$n)                 # imagine the total is published as well
recovered_f <- published_total - toy$n[toy$group == "M"]
stopifnot(recovered_f == 3)                   # the hidden count is recovered by subtraction

# A published rate plus a public population gives the count back:
recovered_cases <- round(attrs$rate_per_1000 * attrs$population / 1000)
stopifnot(all(recovered_cases == attrs$cases))
cat("Counts recovered from rate and population in all areas: TRUE\n")

# 5. Join social and clinical data by area, then release only what is safe -------------
shareable <- attrs %>%
  dplyr::select(area_id, population, deprivation, pm25) %>%
  dplyr::left_join(area_totals_s %>% dplyr::select(area_id, n_cases, suppressed, count_shown),
                   by = "area_id") %>%
  dplyr::mutate(
    n_cases = tidyr::replace_na(n_cases, 0L),
    suppressed = tidyr::replace_na(suppressed, FALSE),
    count_shown = ifelse(is.na(count_shown), "0", count_shown),
    # the rate is hidden whenever the count is hidden
    rate_per_1000 = ifelse(suppressed, NA_real_, round(n_cases / population * 1000, 2))
  )
stopifnot(nrow(shareable) == nrow(attrs),      # one row per area: the join did not duplicate rows
          sum(shareable$n_cases) == nrow(patients))
shareable_out <- shareable %>%
  dplyr::select(area_id, population, deprivation, pm25, cases_shown = count_shown,
                rate_per_1000)
stopifnot(!"patient_id" %in% names(shareable_out), !"n_cases" %in% names(shareable_out))
readr::write_csv(shareable_out, "output/L28_area_table_shareable.csv")
print(head(shareable_out, 8))
cat("Areas with a hidden count:", sum(shareable$suppressed), "of", nrow(shareable), "\n")

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Repeat the area-level suppression with a threshold of 10 and report how many
#    areas are hidden compared with a threshold of 5.
# 2. Check k for area + sex + broad age group (age_broad). Does it reach 5? If not,
#    decide whether you would suppress cells or release only area totals.
# 3. Write check_release(df, quasi_identifiers, k_min) that returns "OK" or a message
#    with the k found, and test it on two quasi-identifier sets.
# Expected: more areas hidden with a threshold of 10; a k below 5 for the finer table;
# a function that returns the right message in both cases.
# Worked solution: lessons/solutions/L28_solution.R
