# ------------------------------------------------------------------------------
# Lesson 29: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/areas_sim.gpkg (simulated)
# Outputs:  none (results printed)
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

areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE) %>%
  dplyr::mutate(log_rate = log((cases + 0.5) / population * 1000))
df <- sf::st_drop_geometry(areas)
f <- log_rate ~ pm25 + deprivation

lw_queen <- spdep::nb2listw(spdep::poly2nb(areas, queen = TRUE), style = "W")
lw_rook <- spdep::nb2listw(spdep::poly2nb(areas, queen = FALSE), style = "W")

# Task 1: Moran's I of the OLS residuals with queen and rook neighbours
ols <- lm(f, data = df)
mq <- spdep::lm.morantest(ols, lw_queen)
mr <- spdep::lm.morantest(ols, lw_rook)
cat("Residual Moran's I, queen:", round(unname(mq$estimate[1]), 3), " p =", signif(mq$p.value, 3), "\n")
cat("Residual Moran's I, rook: ", round(unname(mr$estimate[1]), 3), " p =", signif(mr$p.value, 3), "\n")
cat("Compare the two p-values: if both are small, the conclusion about residual",
    "clustering does not depend on the neighbour definition.\n")

# Task 2: pm25 rate ratio from OLS and from the spatial error model
sem <- spatialreg::errorsarlm(f, data = df, listw = lw_queen)
rr <- function(est, se) c(rate_ratio = exp(est), lower = exp(est - 1.96 * se), upper = exp(est + 1.96 * se))
ols_co <- summary(ols)$coefficients["pm25", ]
sem_co <- summary(sem)$Coef["pm25", ]
print(round(rbind(OLS = rr(ols_co["Estimate"], ols_co["Std. Error"]),
                  SEM = rr(sem_co["Estimate"], sem_co["Std. Error"])), 3))
stopifnot(is.finite(ols_co["Estimate"]), is.finite(sem_co["Estimate"]))

# Task 3: spread of the pm25 coefficient with subsets of 40 and 80 areas
set.seed(2026)
spread <- function(n_sub) {
  est <- replicate(200, coef(lm(f, data = df[sample(nrow(df), n_sub), ]))[["pm25"]])
  quantile(est, c(0.05, 0.95))
}
s40 <- spread(40); s80 <- spread(80)
cat("90% range with 40 areas:", round(s40, 3), " width", round(diff(s40), 3), "\n")
cat("90% range with 80 areas:", round(s80, 3), " width", round(diff(s80), 3), "\n")
stopifnot(diff(s80) < diff(s40))
