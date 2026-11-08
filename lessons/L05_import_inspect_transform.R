# =============================================================================
# Lesson 5 - Importing, inspecting and transforming data (readr, dplyr, tidyr)
# Goal:     Import a file, check its structure, clean it and summarise it.
# Inputs:   data-sim/out/patients_clean.csv, data-sim/out/patients_messy.csv
# Outputs:  output/patients_messy_clean.csv
# Packages: readr, dplyr, tidyr, stringr
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. No real person appears in these files.
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# 1. IMPORT the tidy file, saying what type each column has ------------------------------
patients <- read_csv(
  "data-sim/out/patients_clean.csv",
  col_types = cols(patient_id = col_character(), sex = col_character(), age = col_integer())
)

# 2. INSPECT before you calculate anything ----------------------------------------------------
glimpse(patients)               # types and first values
dim(patients)
count(patients, sex)            # which categories really exist?
summary(patients$age)           # range and centre
colSums(is.na(patients))        # missing values per column
problems(patients)              # import warnings (an empty table is good news)

# 3. TRANSFORM with the dplyr verbs, chained with the native pipe |> -------------------------------
patients |> filter(age >= 65) |> select(patient_id, age) |> arrange(desc(age)) |> head(5)

patients <- patients |>
  mutate(age_band = cut(age, breaks = c(17, 39, 64, Inf), labels = c("18-39", "40-64", "65+")))

# 4. SUMMARISE by group ----------------------------------------------------------------------------------
by_sex <- patients |>
  group_by(sex) |>
  summarise(n = n(), mean_age = mean(age), median_age = median(age), .groups = "drop")
print(by_sex)

# tidyr: counts in long form turned into a small wide table (age band by sex)
age_by_sex <- patients |>
  count(age_band, sex) |>
  pivot_wider(names_from = sex, values_from = n, names_prefix = "sex_", values_fill = 0)
print(age_by_sex)

# 5. The messy file: import with types AND missing-value codes declared ----------------------------------------
messy_raw <- read_csv(
  "data-sim/out/patients_messy.csv",
  col_types = cols(.default = col_character(), weight = col_double(), glucose_mmol_l = col_double()),
  na = c("", "NA", "-999")      # -999 is the code for "missing" in this file
)
glimpse(messy_raw)
count(messy_raw, sex)           # one category written in several ways
count(messy_raw, weight_unit)   # kg and lb mixed in one column
n_missing_glucose <- sum(is.na(messy_raw$glucose_mmol_l))
cat("Missing glucose values:", n_missing_glucose, "\n")

# 6. CLEAN with mutate(): one sex coding and one weight unit -------------------------------------------------------
kg_per_lb <- 0.45359237         # exact definition of the international pound
messy <- messy_raw |>
  mutate(
    sex = str_to_upper(str_sub(str_trim(sex), 1, 1)),
    weight_kg = if_else(weight_unit == "lb", round(weight * kg_per_lb, 1), weight)
  ) |>
  select(patient_id, birth_date, sex, weight_kg, weight_unit, glucose_mmol_l)

count(messy, sex)               # check the result: only F and M should remain
cat("Mean weight before converting units:", round(mean(messy_raw$weight), 1), "\n")
cat("Mean weight in kg after converting:", round(mean(messy$weight_kg), 1), "\n")

# 7. SUMMARISE the cleaned table, then reshape the result with tidyr -------------------------------------------------
summary_by_sex <- messy |>
  group_by(sex) |>
  summarise(
    n = n(),
    n_with_glucose = sum(!is.na(glucose_mmol_l)),
    mean_weight_kg = mean(weight_kg),
    mean_glucose = mean(glucose_mmol_l, na.rm = TRUE),
    .groups = "drop"
  )
print(summary_by_sex)

summary_long <- summary_by_sex |>
  select(sex, mean_weight_kg, mean_glucose) |>
  pivot_longer(cols = c(mean_weight_kg, mean_glucose), names_to = "measure", values_to = "value")
print(summary_long)

messy_complete <- messy |> drop_na(glucose_mmol_l)   # keep rows with a glucose value
cat("Rows with a glucose value:", nrow(messy_complete), "of", nrow(messy), "\n")

# 8. Save the cleaned table; never overwrite the original file ----------------------------------------------------------
write_csv(messy, "output/patients_messy_clean.csv")

# 9. Sanity checks --------------------------------------------------------------------------------------------------------
stopifnot(
  nrow(problems(patients)) == 0,
  all(patients$age >= 18),
  !anyDuplicated(patients$patient_id),
  n_missing_glucose > 0,
  all(messy$sex %in% c("F", "M")),
  mean(messy_raw$weight) > mean(messy$weight_kg),
  nrow(messy_complete) + n_missing_glucose == nrow(messy),
  file.exists("output/patients_messy_clean.csv")
)
cat("Lesson 5 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. In the cleaned table (messy), how many patients have a glucose above 7 mmol/L
#    (an arbitrary cut-off for this exercise) and how many have no glucose value?
# 2. Compute the mean weight_kg by sex and by original weight_unit (kg or lb).
#    The means should be similar: the conversion worked.
# 3. Use count(sex, weight_unit) followed by pivot_wider(names_from = weight_unit,
#    values_from = n) to build a small sex-by-unit table of counts.
# Expected result: three small printed tables. Remember that these are simulated
# data: any difference between groups is noise, not a clinical finding.
# A worked solution is in lessons/solutions/L05_solution.R
# =============================================================================
