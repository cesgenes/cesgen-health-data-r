# ------------------------------------------------------------------------------
# Lesson 27: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/areas_sim_attributes.csv (simulated)
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

# Task 1: toy index with a fourth, invented indicator (percentage of households renting)
toy <- data.frame(
  area = LETTERS[1:8],
  income_median = c(21, 34, 28, 45, 19, 38, 52, 25),
  no_qualifications_pct = c(31, 18, 24, 9, 35, 14, 6, 27),
  overcrowded_pct = c(14, 6, 10, 3, 17, 5, 2, 11),
  renting_pct = c(48, 30, 41, 22, 55, 27, 15, 44)       # invented
)
z <- function(x) (x - mean(x)) / sd(x)
toy$index3 <- (-z(toy$income_median) + z(toy$no_qualifications_pct) + z(toy$overcrowded_pct)) / 3
toy$index4 <- (-z(toy$income_median) + z(toy$no_qualifications_pct) +
               z(toy$overcrowded_pct) + z(toy$renting_pct)) / 4
cat("Most deprived area with 3 indicators:", toy$area[which.max(toy$index3)], "\n")
cat("Most deprived area with 4 indicators:", toy$area[which.max(toy$index4)], "\n")
cat("Rank correlation between the two indices:",
    round(cor(toy$index3, toy$index4, method = "spearman"), 2), "\n")
stopifnot(length(unique(toy$area)) == 8)

# Task 2: rate by deprivation decile
attrs <- readr::read_csv("data-sim/out/areas_sim_attributes.csv", show_col_types = FALSE)
by_decile <- attrs %>%
  dplyr::mutate(decile = dplyr::ntile(deprivation, 10)) %>%
  dplyr::group_by(decile) %>%
  dplyr::summarise(rate_per_1000 = sum(cases) / sum(population) * 1000, .groups = "drop")
print(by_decile)
stopifnot(nrow(by_decile) == 10, by_decile$rate_per_1000[10] > by_decile$rate_per_1000[1])

# Task 3: one sentence, written as a comment and printed
sentence <- paste("The rates describe areas: they say that areas with a higher deprivation",
                  "index had higher rates, not that any resident of such an area is at higher",
                  "risk (ecological data, no individual-level inference).")
cat(sentence, "\n")
