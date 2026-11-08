# ------------------------------------------------------------------------------
# Lesson 30: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/areas_sim.gpkg (simulated)
# Outputs:  output/L30_solution_conclusion.txt
# Packages: sf, spdep, spatialreg, dplyr
# Run from the repository root (RStudio project). Simulated data for teaching purposes.
# ------------------------------------------------------------------------------

library(sf)
library(spdep)
library(spatialreg)
library(dplyr)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE) %>%
  dplyr::mutate(log_rate = log((cases + 0.5) / population * 1000))
df <- sf::st_drop_geometry(areas)
lw <- spdep::nb2listw(spdep::poly2nb(areas, queen = TRUE), style = "W")

pick <- function(label, coefs, term) {
  est <- coefs[term, "Estimate"]; se <- coefs[term, "Std. Error"]
  data.frame(model = label, rate_ratio = exp(est), lower = exp(est - 1.96 * se),
             upper = exp(est + 1.96 * se), stringsAsFactors = FALSE)
}

# Task 1: crude and adjusted rate ratio, and why they differ
crude <- lm(log_rate ~ pm25, data = df)
adjusted <- lm(log_rate ~ pm25 + deprivation, data = df)
r <- cor(df$pm25, df$deprivation)
cat("Correlation between PM2.5 and deprivation:", round(r, 2), "\n")
cat("Because deprivation is higher where PM2.5 is higher and also raises the rate, the crude",
    "estimate mixes the two effects; adjusting separates them.\n")

# Task 2: add the spatial lag model to the results table
sem <- spatialreg::errorsarlm(log_rate ~ pm25 + deprivation, data = df, listw = lw)
sar <- spatialreg::lagsarlm(log_rate ~ pm25 + deprivation, data = df, listw = lw)
results <- rbind(
  pick("Crude", summary(crude)$coefficients, "pm25"),
  pick("Adjusted (OLS)", summary(adjusted)$coefficients, "pm25"),
  pick("Adjusted + spatial error", summary(sem)$Coef, "pm25"),
  pick("Adjusted + spatial lag", summary(sar)$Coef, "pm25")
)
print(results, digits = 3)
stopifnot(nrow(results) == 4, all(is.finite(results$rate_ratio)))

# Task 3: a conclusion with sample size, unit of analysis and one limitation
adj <- results[results$model == "Adjusted + spatial error", ]
conclusion <- c(
  sprintf("In this simulated ecological analysis of %d small areas (the unit of analysis), the rate ratio for a 1-unit higher PM2.5 was %.3f (95%% interval %.3f to %.3f) after adjusting for deprivation and spatial dependence.",
          nrow(df), adj$rate_ratio, adj$lower, adj$upper),
  "This describes differences between areas and says nothing about the risk of any individual.",
  "Limitation: each area has a single exposure value, so people within an area are assumed to share it."
)
writeLines(conclusion, "output/L30_solution_conclusion.txt")
cat(conclusion, sep = "\n")
