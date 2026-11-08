# Solution for lesson 15 (run from the repository root, after L15_data_types_quality.R)
library(readr)
library(dplyr)

source("R/helpers_general.R")
ensure_sim_data()

messy <- read_csv("data-sim/out/patients_messy.csv", show_col_types = FALSE)

# 1. Sentinel counter and percentage for every numeric column
flag_sentinels <- function(df, code = -999) {
  df %>%
    summarise(across(where(is.numeric), list(n = ~ sum(.x == code, na.rm = TRUE),
                                             pct = ~ round(100 * mean(.x == code, na.rm = TRUE), 1)))) %>%
    tidyr::pivot_longer(everything(), names_to = c("column", ".value"),
                        names_pattern = "(.*)_(n|pct)")
}
sentinels <- flag_sentinels(messy)
print(sentinels)

# 2. One verdict per column
verdicts <- tibble(
  column = names(messy),
  verdict = c("identifier: unique, nothing found",
              "text in three date formats: needs parsing (lesson 18)",
              "mixed labels (F, female, Male, m): needs normalising",
              "numbers in two units: depends on weight_unit",
              "unit column: the key to read weight",
              "no NA, but -999 is a disguised missing value")
)
print(verdicts)

# 3. The mix of kg and lb is not caught by completeness, sentinel, duplicate or
#    consistency checks; the plausibility check catches only part of it.
stopifnot(nrow(sentinels) == 2,
          sentinels$n[sentinels$column == "glucose_mmol_l"] > 0)
