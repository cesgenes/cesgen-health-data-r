# Simulated small areas with spatial structure (needs the sf package).

#' A grid of square "areas" with spatially smooth exposure and deprivation, and an outcome count
#' @param nx,ny grid size
#' @return an sf object with columns area_id, pm25, deprivation, population, cases, rate_per_1000
simulate_areas <- function(nx = 14, ny = 14, seed = 2026) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  if (nx < 2 || ny < 2) stop("nx and ny must be at least 2.", call. = FALSE)
  set.seed(seed)
  grid <- sf::st_make_grid(sf::st_bbox(c(xmin = 0, ymin = 0, xmax = nx * 1000, ymax = ny * 1000), crs = sf::st_crs(27700)),
                           n = c(nx, ny))
  n <- length(grid)
  xy <- sf::st_coordinates(sf::st_centroid(grid))
  smooth_field <- function(shift) {
    z <- sin(xy[, 1] / 3500 + shift) + cos(xy[, 2] / 2800 - shift) + rnorm(n, 0, 0.35)
    as.numeric(scale(z))
  }
  f1 <- smooth_field(0.3); f2 <- smooth_field(1.7)
  pm25 <- 9 + 2.5 * f1                                         # micrograms per cubic metre (invented)
  deprivation <- 0.6 * f1 + 0.8 * f2 + rnorm(n, 0, 0.4)         # invented index, correlated with exposure
  deprivation <- as.numeric(scale(deprivation))
  population <- round(runif(n, 800, 4000))
  rate <- exp(log(6) + 0.04 * (pm25 - 9) + 0.25 * deprivation)   # truth: small exposure effect, larger deprivation effect
  cases <- rpois(n, population / 1000 * rate)
  out <- sf::st_sf(area_id = sprintf("A%03d", seq_len(n)), pm25 = round(pm25, 2),
                   deprivation = round(deprivation, 3), population = population, cases = cases,
                   rate_per_1000 = round(cases / population * 1000, 2), geometry = grid)
  out
}
