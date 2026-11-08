# ------------------------------------------------------------------------------
# Lesson 26: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/areas_sim.gpkg (simulated)
# Outputs:  output/L26_exercise_deprivation.png
# Packages: sf, dplyr, ggplot2
# Run from the repository root (RStudio project). Simulated data for teaching purposes.
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(ggplot2)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE)

# Task 1: map deprivation with a different colour scale
p <- ggplot2::ggplot(areas) +
  ggplot2::geom_sf(ggplot2::aes(fill = deprivation), colour = "white", linewidth = 0.15) +
  ggplot2::scale_fill_viridis_c(option = "magma", name = "Deprivation\n(higher = more)") +
  ggplot2::labs(title = "Simulated deprivation index by area", caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L26_exercise_deprivation.png", p, width = 6.5, height = 6, dpi = 150)
stopifnot(file.exists("output/L26_exercise_deprivation.png"))

# Tasks 2 and 3: the monitor experiment as a function of the number of monitors
monitor_experiment <- function(n_monitors, seed = 2026) {
  set.seed(seed)
  bb <- sf::st_bbox(areas)
  mon <- data.frame(
    x = runif(n_monitors, min = as.numeric(bb["xmin"]), max = as.numeric(bb["xmax"])),
    y = runif(n_monitors, min = as.numeric(bb["ymin"]), max = as.numeric(bb["ymax"]))
  )
  mon <- sf::st_as_sf(mon, coords = c("x", "y"), crs = sf::st_crs(areas))
  joined <- sf::st_join(mon, areas[, c("area_id", "pm25")], join = sf::st_intersects)
  stopifnot(nrow(joined) == n_monitors)
  joined$reading <- joined$pm25 + rnorm(n_monitors, 0, 0.5)
  idx <- sf::st_nearest_feature(sf::st_centroid(sf::st_geometry(areas)), joined)
  assigned <- joined$reading[idx]
  data.frame(n_monitors = n_monitors,
             areas_without_monitor = sum(lengths(sf::st_intersects(areas, mon)) == 0),
             mean_abs_error = mean(abs(assigned - areas$pm25)))
}
results <- do.call(rbind, lapply(c(12, 30, 60), monitor_experiment))
print(results, digits = 3)
stopifnot(results$areas_without_monitor[3] < results$areas_without_monitor[1])
cat("The error and the number of uncovered areas usually fall as monitors are added.\n")
