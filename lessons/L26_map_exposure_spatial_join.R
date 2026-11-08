# ------------------------------------------------------------------------------
# Lesson 26: Mapping environmental exposure: maps and spatial joins
# Goal:     map an exposure with ggplot2 + geom_sf, create simulated monitor points,
#           assign them to areas with a spatial join and measure the assignment error.
# Inputs:   data-sim/out/areas_sim.gpkg (simulated small areas)
# Outputs:  output/L26_map_pm25.png, output/L26_map_rate.png,
#           output/L26_map_monitors.png, output/L26_map_nearest_monitor.png
# Packages: sf, dplyr, tidyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

areas <- sf::st_read("data-sim/out/areas_sim.gpkg", quiet = TRUE)
stopifnot(nrow(areas) == 196, sf::st_crs(areas) == sf::st_crs(27700))

# 1. Map the exposure and the outcome ---------------------------------------------
# A map shows where to look; it does not show a cause.
p_pm25 <- ggplot2::ggplot(areas) +
  ggplot2::geom_sf(ggplot2::aes(fill = pm25), colour = "white", linewidth = 0.15) +
  ggplot2::scale_fill_viridis_c(name = "PM2.5\n(simulated)") +
  ggplot2::labs(title = "Simulated PM2.5 by small area",
                subtitle = "Invented units (micrograms per cubic metre)",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L26_map_pm25.png", p_pm25, width = 6.5, height = 6, dpi = 150)

p_rate <- ggplot2::ggplot(areas) +
  ggplot2::geom_sf(ggplot2::aes(fill = rate_per_1000), colour = "white", linewidth = 0.15) +
  ggplot2::scale_fill_viridis_c(option = "plasma", name = "Cases per\n1000 (simulated)") +
  ggplot2::labs(title = "Simulated outcome rate by small area",
                subtitle = "Crude rate; small areas give noisy rates",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L26_map_rate.png", p_rate, width = 6.5, height = 6, dpi = 150)

# 2. Create simulated monitor points inside the grid --------------------------------
set.seed(2026)
n_monitors <- 12
bb <- sf::st_bbox(areas)
monitors <- data.frame(
  monitor_id = sprintf("M%02d", seq_len(n_monitors)),
  x = runif(n_monitors, min = as.numeric(bb["xmin"]), max = as.numeric(bb["xmax"])),
  y = runif(n_monitors, min = as.numeric(bb["ymin"]), max = as.numeric(bb["ymax"]))
)
monitors <- sf::st_as_sf(monitors, coords = c("x", "y"), crs = sf::st_crs(areas))
print(monitors)

# 3. Spatial join: which area contains each monitor? ---------------------------------
# st_join() keeps every monitor and adds the columns of the area it falls in.
monitors_joined <- sf::st_join(monitors, areas[, c("area_id", "pm25")],
                               join = sf::st_intersects)
stopifnot(nrow(monitors_joined) == n_monitors,   # one area per point
          !anyNA(monitors_joined$area_id))
# In real life the reading comes from the instrument. Here we invent one:
# the smooth area value plus measurement noise.
monitors_joined$pm25_reading <- round(monitors_joined$pm25 + rnorm(n_monitors, 0, 0.5), 2)
monitors_joined$pm25 <- NULL
print(sf::st_drop_geometry(monitors_joined))

# The same information with st_intersects(): a list with the monitors in each area
hits <- sf::st_intersects(areas, monitors)
monitors_per_area <- lengths(hits)
stopifnot(sum(monitors_per_area) == n_monitors)
cat("Areas with at least one monitor:", sum(monitors_per_area > 0), "of", nrow(areas), "\n")

# 4. Summarise monitor readings by area ----------------------------------------------
monitor_by_area <- monitors_joined %>%
  sf::st_drop_geometry() %>%
  dplyr::group_by(area_id) %>%
  dplyr::summarise(n_monitors = dplyr::n(),
                   pm25_monitor = mean(pm25_reading), .groups = "drop")
areas_mon <- dplyr::left_join(areas, monitor_by_area, by = "area_id") %>%
  dplyr::mutate(n_monitors = tidyr::replace_na(n_monitors, 0L))
stopifnot(nrow(areas_mon) == nrow(areas), sum(areas_mon$n_monitors) == n_monitors)

# 5. Give every area an exposure: value of the nearest monitor --------------------
centroids <- sf::st_centroid(sf::st_geometry(areas))
nearest_idx <- sf::st_nearest_feature(centroids, monitors_joined)
areas_mon$pm25_nearest <- monitors_joined$pm25_reading[nearest_idx]
assign_error <- areas_mon$pm25_nearest - areas_mon$pm25     # we know the truth in the simulation
cat("Mean absolute assignment error:", round(mean(abs(assign_error)), 2), "\n")
cat("Correlation with the simulated area value:",
    round(cor(areas_mon$pm25_nearest, areas_mon$pm25), 2), "\n")
stopifnot(!anyNA(areas_mon$pm25_nearest))

# 6. Maps with the monitors and the assigned exposure ---------------------------------
p_mon <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = areas, ggplot2::aes(fill = pm25), colour = "white", linewidth = 0.15) +
  ggplot2::geom_sf(data = monitors_joined, shape = 21, fill = "white", colour = "black", size = 2.5) +
  ggplot2::scale_fill_viridis_c(name = "PM2.5\n(simulated)") +
  ggplot2::labs(title = "Simulated monitors over the simulated exposure",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L26_map_monitors.png", p_mon, width = 6.5, height = 6, dpi = 150)

p_near <- ggplot2::ggplot(areas_mon) +
  ggplot2::geom_sf(ggplot2::aes(fill = pm25_nearest), colour = "white", linewidth = 0.15) +
  ggplot2::scale_fill_viridis_c(name = "PM2.5 from\nnearest monitor") +
  ggplot2::labs(title = "Exposure assigned from the nearest monitor",
                subtitle = "Every area gets a value, with an assignment error",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L26_map_nearest_monitor.png", p_near, width = 6.5, height = 6, dpi = 150)
stopifnot(file.exists("output/L26_map_monitors.png"))

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Map deprivation (column deprivation) with a different colour scale and save it
#    as output/L26_exercise_deprivation.png.
# 2. Repeat the monitor experiment with 30 and with 60 monitors (same seed) and
#    compare the mean absolute assignment error with the 12-monitor result.
# 3. Count how many areas contain no monitor in each case.
# Expected: the error usually falls as monitors are added, and the number of areas
# without a monitor falls too. Worked solution: lessons/solutions/L26_solution.R
