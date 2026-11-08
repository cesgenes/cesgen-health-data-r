# =============================================================================
# Lesson 5 - Worked solution of the exercise
# Goal:     Count, summarise and reshape the cleaned simulated patient table.
# Inputs:   data-sim/out/patients_messy.csv (simulated, deliberately messy)
# Outputs:  printed tables only
# Packages: readr, dplyr, tidyr, stringr
# Run from the repository root.
# Simulated data for teaching purposes. Differences between groups are noise.
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
source("R/helpers_general.R")
ensure_sim_data()

# Cleaning steps from the lesson, packaged as a function ---------------------------------
clean_messy_patients <- function(path = "data-sim/out/patients_messy.csv") {
  raw <- read_csv(
    path,
    col_types = cols(.default = col_character(), weight = col_double(), glucose_mmol_l = col_double()),
    na = c("", "NA", "-999")
  )
  kg_per_lb <- 0.45359237
  raw |>
    mutate(
      sex = str_to_upper(str_sub(str_trim(sex), 1, 1)),
      weight_kg = if_else(weight_unit == "lb", round(weight * kg_per_lb, 1), weight)
    ) |>
    select(patient_id, birth_date, sex, weight_kg, weight_unit, glucose_mmol_l)
}
messy <- clean_messy_patients()

# 1. Glucose above 7 mmol/L (arbitrary cut-off) and missing glucose ------------------------
n_above_7 <- messy |> filter(glucose_mmol_l > 7) |> nrow()
n_no_glucose <- sum(is.na(messy$glucose_mmol_l))
cat("Glucose above 7:", n_above_7, "| no glucose value:", n_no_glucose, "\n")

# 2. Mean weight in kg by sex and by original unit -----------------------------------------------
weight_by_group <- messy |>
  group_by(sex, weight_unit) |>
  summarise(n = n(), mean_weight_kg = round(mean(weight_kg), 1), .groups = "drop")
print(weight_by_group)

# 3. A sex-by-unit table of counts -----------------------------------------------------------------
sex_by_unit <- messy |>
  count(sex, weight_unit) |>
  pivot_wider(names_from = weight_unit, values_from = n, values_fill = 0)
print(sex_by_unit)

# Sanity checks ----------------------------------------------------------------------------------------
stopifnot(
  n_above_7 == sum(messy$glucose_mmol_l > 7, na.rm = TRUE),
  n_no_glucose > 0,
  sum(weight_by_group$n) == nrow(messy),
  all(c("kg", "lb") %in% names(sex_by_unit)),
  sum(as.matrix(sex_by_unit[, c("kg", "lb")])) == nrow(messy)
)
cat("Solution for lesson 5 ran correctly.\n")
