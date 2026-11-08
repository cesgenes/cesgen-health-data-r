# ------------------------------------------------------------------------------
# Lesson 30: Integrated case: exposure, deprivation and health outcome
# Goal:     run the whole workflow (check, map, measure clustering, model) and write a
#           conclusion that states what can and cannot be claimed.
# Inputs:   data-sim/out/areas_sim.gpkg (simulated small areas)
# Outputs:  output/L30_map_pm25.png, output/L30_map_deprivation.png,
#           output/L30_map_rate.png, output/L30_results_table.csv,
#           output/L30_conclusion.txt
# Packages: sf, spdep, spatialreg, dplyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. Ecological (area-level) analysis.
# ------------------------------------------------------------------------------

library(sf)
library(spdep)
library(spatialreg)
library(dplyr)
library(ggplot2)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

# 1. Read and check -----------------------------------------------------------------
areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE)
stopifnot(sf::st_crs(areas) == sf::st_crs(27700), nrow(areas) == 196,
          !anyDuplicated(areas$area_id), !anyNA(areas$pm25), !anyNA(areas$deprivation))
areas <- areas %>%
  dplyr::mutate(log_rate = log((cases + 0.5) / population * 1000))
df <- sf::st_drop_geometry(areas)

# 2. Look first: three maps -----------------------------------------------------------
map_variable <- function(data, var, title, legend, option, file) {
  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[var]]), colour = "white", linewidth = 0.15) +
    ggplot2::scale_fill_viridis_c(option = option, name = legend) +
    ggplot2::labs(title = title, caption = sim_caption("Area-level data.")) +
    theme_cesgen()
  ggplot2::ggsave(file, p, width = 6.5, height = 6, dpi = 150)
  invisible(p)
}
map_variable(areas, "pm25", "Simulated PM2.5", "PM2.5", "viridis", "output/L30_map_pm25.png")
map_variable(areas, "deprivation", "Simulated deprivation index", "Index (higher =\nmore deprived)",
             "magma", "output/L30_map_deprivation.png")
map_variable(areas, "rate_per_1000", "Simulated outcome rate", "Cases per\n1000", "plasma",
             "output/L30_map_rate.png")
cat("Correlation between PM2.5 and deprivation:", round(cor(df$pm25, df$deprivation), 2), "\n")

# 3. Measure clustering before modelling ------------------------------------------------
nb <- spdep::poly2nb(areas, queen = TRUE)
lw <- spdep::nb2listw(nb, style = "W")
moran_one <- function(x, label) {
  mt <- spdep::moran.test(x, lw)
  data.frame(variable = label, morans_i = unname(mt$estimate[1]), p_value = mt$p.value,
             stringsAsFactors = FALSE)
}
moran_tab <- rbind(moran_one(df$pm25, "pm25"), moran_one(df$deprivation, "deprivation"),
                   moran_one(df$log_rate, "log outcome rate"))
print(moran_tab)

# 4. Models: crude, adjusted, adjusted + spatial error -----------------------------------
crude <- lm(log_rate ~ pm25, data = df)
adjusted <- lm(log_rate ~ pm25 + deprivation, data = df)
res_moran <- spdep::lm.morantest(adjusted, lw)
cat("Moran's I of the adjusted model residuals:", round(unname(res_moran$estimate[1]), 3),
    " p =", signif(res_moran$p.value, 3), "\n")
sem <- spatialreg::errorsarlm(log_rate ~ pm25 + deprivation, data = df, listw = lw)
resid_sem <- moran_one(as.numeric(residuals(sem)), "SEM residuals")
print(resid_sem)

# 5. One results table: rate ratio per 1 unit of PM2.5 ------------------------------------
pick <- function(label, coefs, term) {
  est <- coefs[term, "Estimate"]; se <- coefs[term, "Std. Error"]
  data.frame(model = label, term = term, rate_ratio = exp(est),
             lower = exp(est - 1.96 * se), upper = exp(est + 1.96 * se),
             stringsAsFactors = FALSE)
}
results <- rbind(
  pick("Crude (exposure only)", summary(crude)$coefficients, "pm25"),
  pick("Adjusted for deprivation (OLS)", summary(adjusted)$coefficients, "pm25"),
  pick("Adjusted + spatial error (SEM)", summary(sem)$Coef, "pm25"),
  pick("Deprivation, per 1 SD (OLS)", summary(adjusted)$coefficients, "deprivation")
)
print(results, digits = 3)
stopifnot(all(is.finite(results$rate_ratio)), all(results$lower < results$upper))
write.csv(results, "output/L30_results_table.csv", row.names = FALSE)

# 6. The conclusion: what can and cannot be claimed ---------------------------------------
adj <- results[results$model == "Adjusted + spatial error (SEM)", ]
crd <- results[results$model == "Crude (exposure only)", ]
conclusion <- c(
  "CONCLUSION (simulated data for teaching purposes)",
  sprintf("What we did: an ecological analysis of %d small areas, with area-level PM2.5, a deprivation index and an outcome rate.", nrow(df)),
  sprintf("What we found: the crude rate ratio per 1 unit of PM2.5 was %.3f; after adjusting for deprivation and allowing for spatial dependence it was %.3f (95%% interval %.3f to %.3f).",
          crd$rate_ratio, adj$rate_ratio, adj$lower, adj$upper),
  "What this supports: across these areas, higher exposure went with a higher outcome rate after adjusting for deprivation, and the pattern is spatially clustered.",
  "What this does not support: a statement about any individual's risk (ecological analysis, no individual-level inference), proof of causation, or that the result holds with other area boundaries.",
  "What would strengthen it: individual-level data with home location, a better exposure model than one value per area, other boundaries and more areas as sensitivity analyses."
)
writeLines(conclusion, "output/L30_conclusion.txt")
cat(conclusion, sep = "\n")

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Run the script and compare the crude and the adjusted rate ratio for PM2.5.
#    Explain in two sentences why they differ, using the correlation printed in step 2.
# 2. Add a spatial lag model (spatialreg::lagsarlm) to the results table.
# 3. Edit the conclusion so that it also states the sample size, the unit of analysis
#    and one limitation of using the simulated exposure as a single value per area.
# Expected: the crude ratio is larger than the adjusted one because deprivation travels
# with exposure; the spatial models give a similar adjusted ratio; a conclusion that
# mentions areas, not individuals. Worked solution: lessons/solutions/L30_solution.R
