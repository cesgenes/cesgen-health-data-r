# ------------------------------------------------------------------------------
# Lesson 29: Spatial autocorrelation and spatial regression
# Goal:     build neighbours, measure spatial autocorrelation (Moran's I), fit an
#           ordinary and two spatial regression models, compare them, check the
#           residuals and see how small samples and area boundaries change results.
# Inputs:   data-sim/out/areas_sim.gpkg (simulated small areas)
# Outputs:  output/L29_moran_scatter.png
# Packages: sf, spdep, spatialreg, dplyr, ggplot2, broom
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. Order of work: map, measure clustering, model.
# ------------------------------------------------------------------------------

library(sf)
library(spdep)
library(spatialreg)
library(dplyr)
library(ggplot2)
library(broom)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE)
# Outcome on the log scale; 0.5 is added so that areas with zero cases stay defined.
areas <- areas %>%
  dplyr::mutate(log_rate = log((cases + 0.5) / population * 1000))
df <- sf::st_drop_geometry(areas)              # plain table, same row order as 'areas'
stopifnot(nrow(df) == 196, all(is.finite(df$log_rate)))

# 1. Neighbours: who touches whom? ----------------------------------------------------
nb_queen <- spdep::poly2nb(areas, queen = TRUE)  # share an edge or a corner
nb_rook <- spdep::poly2nb(areas, queen = FALSE)  # share an edge
print(summary(spdep::card(nb_queen)))            # number of neighbours per area
stopifnot(length(nb_queen) == nrow(areas),
          min(spdep::card(nb_queen)) == 3, max(spdep::card(nb_queen)) == 8,
          min(spdep::card(nb_rook)) == 2, max(spdep::card(nb_rook)) == 4)
lw <- spdep::nb2listw(nb_queen, style = "W")     # row-standardised weights

# 2. Measure clustering: Moran's I ------------------------------------------------------
moran_summary <- function(x, listw, label) {
  mt <- spdep::moran.test(x, listw)
  data.frame(variable = label, morans_i = unname(mt$estimate[1]), p_value = mt$p.value,
             stringsAsFactors = FALSE)
}
moran_table <- rbind(
  moran_summary(df$pm25, lw, "pm25"),
  moran_summary(df$deprivation, lw, "deprivation"),
  moran_summary(df$log_rate, lw, "log outcome rate")
)
print(moran_table)

# Permutation version of the test for the outcome
set.seed(2026)
mc <- spdep::moran.mc(df$log_rate, lw, nsim = 999)
cat("Moran's I (permutation):", round(unname(mc$statistic), 3), " p =", mc$p.value, "\n")

# Reference: shuffling the values destroys the spatial pattern, so I should be near 0
shuffled <- moran_summary(sample(df$log_rate), lw, "shuffled outcome")
print(shuffled)

# Moran scatter plot: each area against the average of its neighbours
z <- as.numeric(scale(df$log_rate))
lag_z <- spdep::lag.listw(lw, z)
p_moran <- ggplot2::ggplot(data.frame(z = z, lag_z = lag_z), ggplot2::aes(x = z, y = lag_z)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey70") +
  ggplot2::geom_vline(xintercept = 0, colour = "grey70") +
  ggplot2::geom_point(colour = cesgen_blue[["mid"]], alpha = 0.7) +
  ggplot2::geom_smooth(method = "lm", se = FALSE, colour = cesgen_blue[["accent"]]) +
  ggplot2::labs(title = "Moran scatter plot of the log outcome rate",
                x = "Standardised value in the area", y = "Average of its neighbours",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L29_moran_scatter.png", p_moran, width = 5.5, height = 5, dpi = 150)

# 3. Ordinary regression and its residuals ------------------------------------------------
f <- log_rate ~ pm25 + deprivation
ols <- lm(f, data = df)
print(summary(ols))
lm_moran <- spdep::lm.morantest(ols, lw)         # Moran's I of the OLS residuals
resid_table <- data.frame(variable = "OLS residuals",
                          morans_i = unname(lm_moran$estimate[1]),
                          p_value = lm_moran$p.value, stringsAsFactors = FALSE)

# 4. Spatial models: spatial error (SEM) and spatial lag (SAR) -------------------------------
sem <- spatialreg::errorsarlm(f, data = df, listw = lw)
sar <- spatialreg::lagsarlm(f, data = df, listw = lw)
print(summary(sem))
print(summary(sar))
cat("SEM lambda:", round(sem$lambda, 3), "  SAR rho:", round(sar$rho, 3), "\n")

resid_table <- rbind(
  resid_table,
  moran_summary(as.numeric(residuals(sem)), lw, "SEM residuals"),
  moran_summary(as.numeric(residuals(sar)), lw, "SAR residuals")
)
print(resid_table)

# 5. Compare the models --------------------------------------------------------------------
aic_safe <- function(m) tryCatch(AIC(m), error = function(e) NA_real_)
aic_table <- data.frame(model = c("OLS", "SEM", "SAR"),
                        AIC = c(aic_safe(ols), aic_safe(sem), aic_safe(sar)))
print(aic_table)

coef_table <- function(label, coefs) {
  data.frame(model = label, term = rownames(coefs),
             estimate = coefs[, "Estimate"], se = coefs[, "Std. Error"], row.names = NULL,
             stringsAsFactors = FALSE)
}
tab <- rbind(coef_table("OLS", summary(ols)$coefficients),
             coef_table("SEM", summary(sem)$Coef),
             coef_table("SAR", summary(sar)$Coef))
tab <- tab[tab$term %in% c("pm25", "deprivation"), ]
tab$rate_ratio <- exp(tab$estimate)                          # per 1 unit of the covariate
tab$lower <- exp(tab$estimate - 1.96 * tab$se)
tab$upper <- exp(tab$estimate + 1.96 * tab$se)
print(tab, digits = 3)
stopifnot(all(is.finite(tab$estimate)), nrow(tab) == 6)

# 5b. A count model for comparison. The outcome is a COUNT of cases and each area has a different
# population, so a quasi-Poisson model with log(population) as an offset models the counts
# directly. Its rate ratios are comparable with the ones above (per 1 unit of the covariate).
pois <- glm(cases ~ pm25 + deprivation + offset(log(population / 1000)),
            data = df, family = quasipoisson)
pois_coef <- summary(pois)$coefficients[c("pm25", "deprivation"), , drop = FALSE]
pois_tab <- data.frame(
  model = "Quasi-Poisson", term = rownames(pois_coef), estimate = pois_coef[, "Estimate"],
  se = pois_coef[, "Std. Error"], row.names = NULL, stringsAsFactors = FALSE
)
pois_tab$rate_ratio <- exp(pois_tab$estimate)
pois_tab$lower <- exp(pois_tab$estimate - 1.96 * pois_tab$se)
pois_tab$upper <- exp(pois_tab$estimate + 1.96 * pois_tab$se)
print(pois_tab, digits = 3)
print(moran_summary(residuals(pois, type = "pearson"), lw, "Quasi-Poisson residuals"))
stopifnot(all(is.finite(pois_tab$estimate)))
# Limit: this is a comparison model, not a spatial model of counts. Its residuals can still be
# spatially autocorrelated (Moran's I above); the spatial error and lag models handle that, but
# only for the log rate.
# The linear model on the log rate and the count model should tell a similar story here; the
# count model is the one that matches how a count of cases is produced, and it needs no 0.5.

# 6. Cautions: small samples and the modifiable areal unit problem -------------------------------
# 6a. Small samples: fit the same OLS on 200 random subsets of 40 areas.
set.seed(2026)
sub_est <- replicate(200, {
  idx <- sample(nrow(df), 40)
  coef(lm(f, data = df[idx, ]))[["pm25"]]
})
cat("pm25 coefficient on 40 areas (5%, 50%, 95%):", round(quantile(sub_est, c(0.05, 0.5, 0.95)), 3), "\n")
cat("pm25 coefficient on all 196 areas:", round(coef(ols)[["pm25"]], 3), "\n")

# 6b. MAUP: merge the 14 x 14 grid into 7 x 7 blocks of 2 x 2 areas and refit.
xy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(areas)))
df$block <- paste(floor(xy[, 1] / 2000), floor(xy[, 2] / 2000))
blocks <- df %>%
  dplyr::group_by(block) %>%
  # population-weighted means first, because 'population' is redefined as a sum below
  dplyr::summarise(pm25 = weighted.mean(pm25, population),
                   deprivation = weighted.mean(deprivation, population),
                   cases = sum(cases), population = sum(population), .groups = "drop") %>%
  dplyr::mutate(log_rate = log((cases + 0.5) / population * 1000))
stopifnot(nrow(blocks) == 49)
ols_blocks <- lm(f, data = blocks)
maup <- rbind(
  data.frame(units = "196 small areas", broom::tidy(ols)[, c("term", "estimate", "std.error")]),
  data.frame(units = "49 blocks", broom::tidy(ols_blocks)[, c("term", "estimate", "std.error")])
)
print(maup[maup$term != "(Intercept)", ], digits = 3)

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Compute Moran's I for the OLS residuals with rook neighbours instead of queen
#    neighbours. Does the conclusion about residual clustering change?
# 2. Compare the pm25 rate ratio (with its interval) from OLS and SEM in one sentence.
# 3. Repeat the small-sample experiment with subsets of 80 areas and compare the
#    spread of the pm25 coefficient with the 40-area result.
# Expected: clearly positive Moran's I for the outcome and for the exposure; a much
# narrower spread with 80 areas than with 40. Worked solution: lessons/solutions/L29_solution.R
