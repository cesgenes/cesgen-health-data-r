# ------------------------------------------------------------------------------
# Lesson 25: worked solution to the "Try this" tasks
# Inputs:   data-sim/out/areas_sim.gpkg (simulated)
# Outputs:  output/L25_exercise.png
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

# Task 1: EPSG code and unit of the coordinates
cat("EPSG:", sf::st_crs(areas)$epsg, "\n")
cat("Unit:", sf::st_crs(areas)$units_gdal, "\n")      # "metre" for a projected CRS such as 27700
stopifnot(sf::st_crs(areas) == sf::st_crs(27700), !isTRUE(sf::st_is_longlat(areas)))

# Task 2: transform to EPSG:4326 and measure the bounding box in degrees
areas_ll <- sf::st_transform(areas, 4326)
bb <- sf::st_bbox(areas_ll)
width_deg <- as.numeric(bb["xmax"] - bb["xmin"])
height_deg <- as.numeric(bb["ymax"] - bb["ymin"])
cat("Box width (degrees):", round(width_deg, 3), " height (degrees):", round(height_deg, 3), "\n")
stopifnot(width_deg > 0, width_deg < 1, height_deg > 0, height_deg < 1)

# Task 3: highlight the areas with population above 3500
big <- areas %>% dplyr::filter(population > 3500)
cat("Areas above 3500 residents:", nrow(big), "\n")
p <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = areas, fill = "grey95", colour = "white") +
  ggplot2::geom_sf(data = big, fill = cesgen_blue[["accent"]], colour = "white") +
  ggplot2::labs(title = "Areas with more than 3500 residents (simulated)",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L25_exercise.png", p, width = 6, height = 6, dpi = 150)
stopifnot(file.exists("output/L25_exercise.png"), nrow(big) < nrow(areas))
