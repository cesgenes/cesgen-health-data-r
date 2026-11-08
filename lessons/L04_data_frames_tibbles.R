# =============================================================================
# Lesson 4 - Data tables with the tidyverse: data frames and tibbles
# Goal:     Create a tibble, read its rows, columns and variable types, and read
#           the simulated patient files.
# Inputs:   data-sim/out/patients_clean.csv, data-sim/out/patients_messy.csv
# Outputs:  printed tables only
# Packages: dplyr (tibble() and glimpse() come with it), readr
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. The small toy table below is invented.
# =============================================================================

library(dplyr)
library(readr)
source("R/helpers_general.R")
ensure_sim_data()

# 1. A tibble made by hand: one argument per column --------------------------------------
toy <- tibble(
  patient_id = c("T01", "T02", "T03", "T04", "T05"),
  age = c(34L, 58L, 71L, 45L, 66L),
  sex = c("F", "M", "F", "F", "M"),
  smoker = c(FALSE, TRUE, FALSE, FALSE, TRUE),
  visit_date = as.Date(c("2026-01-12", "2026-01-13", "2026-01-13", "2026-01-14", "2026-01-15")),
  systolic_bp = c(118, 142, 150, NA, 135)
)
print(toy)
dim(toy)                        # rows, columns
names(toy)
glimpse(toy)                    # one line per column: name, type, first values
vapply(toy, function(x) class(x)[1], character(1))

# 2. Reading parts of a table -----------------------------------------------------------------
toy$age                         # one column as a vector
toy[["age"]]                    # the same, with double brackets
toy[2, ]                        # row 2, all columns
toy[toy$age > 60, ]             # rows that meet a condition (T03 and T05)
toy[, c("patient_id", "age")]   # two columns (a tibble stays a tibble)

# 3. Types of variable and how to change them -------------------------------------------------------
toy$sex <- factor(toy$sex, levels = c("F", "M"))       # a categorical variable
levels(toy$sex)
table(toy$sex)

toy$age_band <- cut(toy$age, breaks = c(17, 39, 64, Inf),
                    labels = c("18-39", "40-64", "65+"), ordered_result = TRUE)
table(toy$age_band)             # an ordered categorical variable: 1, 2 and 2 patients

sum(is.na(toy$systolic_bp))     # missing values: 1
colSums(is.na(toy))             # missing values in every column
mean(toy$smoker)                # a logical column: the proportion of TRUE (0.4)

# 4. Read the simulated clean patient file -------------------------------------------------------------
patients <- read_csv("data-sim/out/patients_clean.csv", show_col_types = FALSE)
glimpse(patients)
dim(patients)
table(patients$sex)
summary(patients$age)

patients$age_band <- cut(patients$age, breaks = c(17, 39, 64, Inf),
                         labels = c("18-39", "40-64", "65+"))
table(patients$age_band)
head(patients, 5)

# 5. A first look at the messy file: the types already tell a story ------------------------------------------
messy <- read_csv("data-sim/out/patients_messy.csv", show_col_types = FALSE)
glimpse(messy)
vapply(messy, function(x) class(x)[1], character(1))
head(messy$birth_date, 5)       # text in different formats, not a date yet
table(messy$weight_unit)        # weight comes in kg and lb
summary(messy$glucose_mmol_l)   # the minimum shows a code for missing values (-999)

# 6. Sanity checks ----------------------------------------------------------------------------------------------
stopifnot(
  nrow(toy) == 5, ncol(toy) == 7,
  is.factor(toy$sex), is.ordered(toy$age_band),
  sum(is.na(toy$systolic_bp)) == 1,
  is.character(patients$patient_id), is.numeric(patients$age),
  !anyDuplicated(patients$patient_id),
  all(patients$age >= 18 & patients$age <= 95),
  is.character(messy$birth_date),
  min(messy$glucose_mmol_l) < 0
)
cat("Lesson 4 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Create a tibble called my_patients with four invented patients and five
#    columns: an identifier (text), an age (integer), a sex (text), a logical
#    variable (for example, diabetic) and a visit date (Date).
# 2. Convert the sex column to a factor and check the types with glimpse().
# 3. Create the column age_band in patients_clean (as above) and use table() to
#    count how many patients are aged 65 or more.
# Expected result: glimpse() shows <chr>, <int>, <fct>, <lgl> and <date>, and the
# count of the "65+" group equals sum(patients$age >= 65).
# A worked solution is in lessons/solutions/L04_solution.R
# =============================================================================
