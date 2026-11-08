# =============================================================================
# Lesson 3 - First steps in R: objects, vectors and functions
# Goal:     Create objects, work with whole vectors and call (and write) functions.
# Inputs:   data-sim/out/patients_clean.csv (simulated patients)
# Outputs:  printed results only
# Packages: none (base R only)
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. The weights and heights below are invented.
# =============================================================================

source("R/helpers_general.R")
ensure_sim_data()

# 1. Objects: a value with a name ---------------------------------------------------
age_years <- 47                 # a number
patient_label <- "Patient 001"  # text (always in quotes)
is_smoker <- FALSE              # a logical value: TRUE or FALSE
class(age_years)
class(patient_label)
class(is_smoker)

# 2. Vectors: several values of the same type, combined with c() -----------------------
weight_kg <- c(62, 80.5, 95, 70)
height_m <- c(1.60, 1.75, 1.82, 1.68)

# R works on whole vectors at once: no loop is needed
bmi <- weight_kg / height_m^2
bmi <- round(bmi, 1)
print(bmi)                      # 24.2 26.3 28.7 24.8
names(bmi) <- c("P1", "P2", "P3", "P4")
print(bmi)

# Adult BMI bands (WHO): under 18.5, 18.5-24.9, 25-29.9, 30 or more.
# They are screening categories, not a diagnosis.
bmi_band <- cut(bmi, breaks = c(0, 18.5, 25, 30, Inf), right = FALSE,
                labels = c("under 18.5", "18.5-24.9", "25-29.9", "30+"))
print(bmi_band)

# 3. Choosing and counting with conditions -----------------------------------------------
bmi[2]                          # the second element
bmi[bmi >= 25]                  # the elements that meet a condition
bmi >= 25                       # a condition returns TRUE/FALSE for each element
sum(bmi >= 25)                  # TRUE counts as 1, so sum() counts: 2
mean(bmi >= 25)                 # ... and mean() gives the proportion: 0.5
which(bmi >= 25)                # positions of the TRUE values

# 4. Functions: call them with arguments, by position or by name ---------------------------
round(3.14159, 2)
round(x = 3.14159, digits = 2)

# Missing values are written NA. Most summaries return NA if one value is missing.
glucose_mmol_l <- c(5.4, NA, 6.1, 5.9)
mean(glucose_mmol_l)                    # NA
mean(glucose_mmol_l, na.rm = TRUE)      # 5.8
sum(is.na(glucose_mmol_l))              # how many values are missing: 1

# 5. Write your own function -------------------------------------------------------------------
bmi_calc <- function(weight_kg, height_m) {
  stopifnot(all(weight_kg > 0), all(height_m > 0))   # stop early on impossible values
  weight_kg / height_m^2                             # the last line is what is returned
}
round(bmi_calc(70, 1.75), 1)    # 22.9
stopifnot(all.equal(round(bmi_calc(weight_kg, height_m), 1), unname(bmi)))

# 6. Real columns are vectors: the age of the simulated patients -------------------------------------
patients <- read.csv("data-sim/out/patients_clean.csv", stringsAsFactors = FALSE)
age <- patients$age             # $ extracts one column as a vector
length(age)

describe_vector <- function(x) {
  c(n = sum(!is.na(x)), mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE), median = median(x, na.rm = TRUE), max = max(x, na.rm = TRUE))
}
print(round(describe_vector(age), 1))

share_65_plus <- mean(age >= 65)
cat("Share of patients aged 65 or more:", round(100 * share_65_plus, 1), "%\n")
print(table(patients$sex))

# 7. Sanity checks ---------------------------------------------------------------------------------------
stopifnot(
  length(age) == nrow(patients),
  all(age >= 18 & age <= 95),
  share_65_plus >= 0 && share_65_plus <= 1,
  is.na(mean(glucose_mmol_l)),
  isTRUE(all.equal(mean(glucose_mmol_l, na.rm = TRUE), 5.8))
)
cat("Lesson 3 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Invent the weight (kg) and height (m) of five people and compute their BMI
#    with bmi_calc(). Count how many have a BMI of 25 or more.
# 2. Write a function pct_above(x, cutoff) that returns the percentage of values
#    greater than or equal to the cutoff (ignore missing values). Use it to get the
#    percentage of simulated patients aged 65 or more.
# 3. In one sentence, explain why mean(glucose_mmol_l) returned NA above.
# Expected result: your own BMI vector and count, and a percentage that equals
# 100 * mean(age >= 65). A worked solution is in lessons/solutions/L03_solution.R
# =============================================================================
