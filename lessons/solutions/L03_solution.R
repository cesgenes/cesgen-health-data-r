# =============================================================================
# Lesson 3 - Worked solution of the exercise
# Goal:     BMI for five invented people and a reusable percentage function.
# Inputs:   data-sim/out/patients_clean.csv (simulated patients)
# Outputs:  printed results only
# Packages: none (base R only)
# Run from the repository root.
# Simulated data for teaching purposes. The weights and heights are invented.
# =============================================================================

source("R/helpers_general.R")
ensure_sim_data()

# 1. BMI for five invented people ------------------------------------------------------
bmi_calc <- function(weight_kg, height_m) {
  stopifnot(all(weight_kg > 0), all(height_m > 0))
  weight_kg / height_m^2
}
weight_kg <- c(58, 72, 88, 101, 66)
height_m <- c(1.62, 1.78, 1.70, 1.85, 1.58)
bmi <- round(bmi_calc(weight_kg, height_m), 1)
print(bmi)
n_bmi_25_or_more <- sum(bmi >= 25)
cat("People with BMI >= 25:", n_bmi_25_or_more, "\n")

# 2. A percentage function that ignores missing values -----------------------------------
pct_above <- function(x, cutoff) {
  100 * mean(x >= cutoff, na.rm = TRUE)
}
patients <- read.csv("data-sim/out/patients_clean.csv", stringsAsFactors = FALSE)
pct_65_plus <- pct_above(patients$age, 65)
cat("Percentage of patients aged 65 or more:", round(pct_65_plus, 1), "%\n")

# 3. Why does mean() return NA? ----------------------------------------------------------------
# Because one value is missing (NA) and R cannot know what it would have been; the
# argument na.rm = TRUE tells R to leave missing values out of the calculation.
glucose_mmol_l <- c(5.4, NA, 6.1, 5.9)
mean_without_na <- mean(glucose_mmol_l, na.rm = TRUE)
print(mean_without_na)

# 4. Sanity checks ---------------------------------------------------------------------------------
stopifnot(
  length(bmi) == 5,
  n_bmi_25_or_more == sum(weight_kg / height_m^2 >= 25),
  isTRUE(all.equal(pct_65_plus, 100 * mean(patients$age >= 65))),
  isTRUE(all.equal(mean_without_na, 5.8))
)
cat("Solution for lesson 3 ran correctly.\n")
