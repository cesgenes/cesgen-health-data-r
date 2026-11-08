# ------------------------------------------------------------------------------
# Lesson 27: Social determinants of health: what they are and how they are measured
# Goal:     build a small composite deprivation index from toy indicators and see
#           how an area-level deprivation index relates to health outcomes.
# Inputs:   data-sim/out/areas_sim_attributes.csv (simulated small areas)
# Outputs:  output/L27_rate_by_quintile.png
# Packages: dplyr, readr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. The toy indicators below are invented.
# ------------------------------------------------------------------------------

library(dplyr)
library(readr)
library(ggplot2)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

# 1. A composite index from three toy indicators --------------------------------------
# Eight invented areas with three indicators measured in different units.
toy <- data.frame(
  area = LETTERS[1:8],
  income_median = c(21, 34, 28, 45, 19, 38, 52, 25),          # thousands, invented
  no_qualifications_pct = c(31, 18, 24, 9, 35, 14, 6, 27),     # percentage of adults
  overcrowded_pct = c(14, 6, 10, 3, 17, 5, 2, 11)              # percentage of households
)
z <- function(x) (x - mean(x)) / sd(x)                         # put indicators on one scale
# Direction first: high income means LESS deprivation, so its sign is flipped.
toy$deprivation_index <- (-z(toy$income_median) +
                          z(toy$no_qualifications_pct) +
                          z(toy$overcrowded_pct)) / 3
toy$rank_most_deprived <- rank(-toy$deprivation_index)         # 1 = most deprived
print(toy[order(toy$rank_most_deprived), ])
stopifnot(which.max(toy$deprivation_index) == 5,               # area E
          which.min(toy$deprivation_index) == 7)               # area G

# Equal weights are a choice. Give income double weight and see whether the order changes.
toy$index_income_x2 <- (-2 * z(toy$income_median) +
                        z(toy$no_qualifications_pct) +
                        z(toy$overcrowded_pct)) / 4
cat("Same ranking with income counted twice:",
    identical(order(toy$deprivation_index), order(toy$index_income_x2)), "\n")

# 2. Quintiles of the simulated area-level index ---------------------------------------
# In this simulation a higher value of 'deprivation' means more deprived.
attrs <- readr::read_csv("data-sim/out/areas_sim_attributes.csv", show_col_types = FALSE)
attrs <- attrs %>%
  dplyr::mutate(dep_quintile = factor(dplyr::ntile(deprivation, 5), levels = 1:5,
                                      labels = c("Q1 least deprived", "Q2", "Q3", "Q4",
                                                 "Q5 most deprived")))
stopifnot(all(table(attrs$dep_quintile) >= 39))               # about 39-40 areas each

# 3. Outcome rate by quintile: rates from summed counts, not averages of rates -----------
by_q <- attrs %>%
  dplyr::group_by(dep_quintile) %>%
  dplyr::summarise(n_areas = dplyr::n(),
                   population = sum(population),
                   cases = sum(cases),
                   rate_per_1000 = sum(cases) / sum(population) * 1000,
                   mean_pm25 = mean(pm25), .groups = "drop")
print(by_q)
rate_ratio_q5_q1 <- by_q$rate_per_1000[5] / by_q$rate_per_1000[1]
cat("Rate ratio, most vs least deprived quintile:", round(rate_ratio_q5_q1, 2), "\n")
stopifnot(by_q$rate_per_1000[5] > by_q$rate_per_1000[1])

p_q <- ggplot2::ggplot(by_q, ggplot2::aes(x = dep_quintile, y = rate_per_1000)) +
  ggplot2::geom_col(fill = cesgen_blue[["mid"]]) +
  ggplot2::labs(title = "Simulated outcome rate by deprivation quintile of the area",
                x = NULL, y = "Cases per 1000 residents",
                caption = sim_caption("Area-level (ecological) data.")) +
  theme_cesgen() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
ggplot2::ggsave("output/L27_rate_by_quintile.png", p_q, width = 6.5, height = 5, dpi = 150)

# 4. Deprivation and exposure travel together ------------------------------------------
cat("Correlation between deprivation and PM2.5 across areas:",
    round(cor(attrs$deprivation, attrs$pm25), 2), "\n")

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Rebuild the toy index with a fourth invented indicator (for example, the
#    percentage of households renting) and check whether the most deprived area changes.
# 2. Recompute the rate by deprivation decile (ntile(deprivation, 10)) and compare the
#    gradient with the quintile result.
# 3. Write one sentence on why the quintile result describes areas, not residents.
# Expected: a ranking that mostly keeps its order; a rate that rises across deciles;
# a sentence that mentions the ecological (area-level) nature of the data.
# Worked solution: lessons/solutions/L27_solution.R
