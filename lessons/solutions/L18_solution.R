# Solution for lesson 18 (run from the repository root).
library(readr)
library(dplyr)
library(stringr)

source("R/helpers_general.R")
ensure_sim_data()

# Re-use the cleaning functions and the cleaned table by running the lesson script
source("lessons/L18_clean_clinical_data.R")

# 1. Every date was parsed
n_unparsed <- sum(is.na(messy_clean$birth_date_clean))
cat("Unparsed dates:", n_unparsed, "\n")

# 2. Glucose in mg/dL: the median should be about 18 times the mmol/L median
ratio <- median(messy_clean$glucose_mg_dl, na.rm = TRUE) /
  median(messy_clean$glucose_mmol_l, na.rm = TRUE)
cat("Median ratio mg/dL : mmol/L =", round(ratio, 2), "\n")

# 3. Normalise the strings and look them up in the phenotype dictionary
strings <- c("J45.0", "j450", " k21 ", "F32.9")
normalised <- normalise_icd10(strings)
lookup <- tibble(raw = strings, icd10 = normalised) %>%
  left_join(phenotype_map %>% select(icd10, phenotype), by = "icd10")
print(lookup)

stopifnot(n_unparsed == 0,
          abs(ratio - 18.016) < 0.01,
          identical(normalised, c("J45", "J45", "K21", "F32")),
          !any(is.na(lookup$phenotype)))
