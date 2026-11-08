# ------------------------------------------------------------------------------
# Lesson 25: Spatial data in R: coordinates, projections and the sf package
# Goal:     read a spatial layer, check its coordinate reference system (CRS),
#           change it with st_transform() and draw it.
# Inputs:   data-sim/out/areas_sim.gpkg, data-sim/out/areas_sim_attributes.csv
#           (simulated small areas; they do not correspond to any real place)
# Outputs:  output/L25_grid_map.png
# Packages: sf, dplyr, readr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(readr)
library(ggplot2)

source("R/helpers_general.R")
source("data-sim/extra_4.R")
ensure_sim_data()
ensure_areas_data()
dir.create("output", showWarnings = FALSE)

# 1. Read the spatial layer -----------------------------------------------------
gpkg_path <- "data-sim/out/areas_sim.gpkg"
print(sf::st_layers(gpkg_path))                 # which layers does the file contain?
areas <- sf::st_read(gpkg_path, quiet = TRUE)
print(class(areas))                             # an sf object is also a data frame
print(head(areas, 3))
stopifnot(inherits(areas, "sf"), nrow(areas) == 196)

# 2. Check the coordinate reference system ---------------------------------------
crs_areas <- sf::st_crs(areas)
print(crs_areas$input)                          # name of the CRS
print(crs_areas$epsg)                           # its EPSG code
print(sf::st_is_longlat(areas))                 # FALSE: coordinates are in metres, not degrees
stopifnot(crs_areas == sf::st_crs(27700))       # British National Grid

# 3. Look at the geometry ------------------------------------------------------
print(sf::st_geometry_type(areas, by_geometry = FALSE))
print(sf::st_bbox(areas))                       # bounding box in metres
cell_area_m2 <- as.numeric(sf::st_area(areas))  # area of each cell in square metres
print(summary(cell_area_m2))
stopifnot(all(abs(cell_area_m2 - 1e6) < 1))     # every cell is 1 km x 1 km
cat("Total area (km2):", sum(cell_area_m2) / 1e6, "\n")
stopifnot(all(sf::st_is_valid(areas)))          # no broken polygons

# 4. Change the CRS: st_transform() recalculates the coordinates -----------------
areas_ll <- sf::st_transform(areas, 4326)       # 4326 = WGS 84, longitude/latitude in degrees
print(sf::st_bbox(areas_ll))
stopifnot(isTRUE(sf::st_is_longlat(areas_ll)))
areas_back <- sf::st_transform(areas_ll, 27700) # and back to the British National Grid
centroids_orig <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(areas)))
centroids_back <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(areas_back)))
max_shift <- max(abs(centroids_orig - centroids_back))
cat("Largest round-trip shift (metres):", signif(max_shift, 3), "\n")
# The grid starts at the false origin of the British National Grid, outside the area where the
# accurate OSTN15 grid shift applies, so PROJ falls back to an approximate transformation
# and a round trip can move points by tens of metres. That is still small against 1 km cells.
stopifnot(max_shift < 100)

# 5. Relabelling is not transforming ---------------------------------------------
# A point in central London given as longitude, latitude (public coordinates)
pt_ll <- sf::st_sfc(sf::st_point(c(-0.1276, 51.5072)), crs = 4326)
pt_bng <- sf::st_transform(pt_ll, 27700)        # correct: new numbers, same place
print(sf::st_coordinates(pt_bng))
stopifnot(sf::st_coordinates(pt_bng)[1, "X"] > 5e5, sf::st_coordinates(pt_bng)[1, "X"] < 6e5,
          sf::st_coordinates(pt_bng)[1, "Y"] > 1.5e5, sf::st_coordinates(pt_bng)[1, "Y"] < 2.1e5)
pt_wrong <- suppressWarnings(sf::st_set_crs(pt_ll, 27700))  # wrong: same numbers, new label
print(sf::st_coordinates(pt_wrong))             # still -0.1276, 51.5072, now "metres"

# 6. Attach a table of attributes by key -----------------------------------------
attrs <- readr::read_csv("data-sim/out/areas_sim_attributes.csv", show_col_types = FALSE)
stopifnot(!anyDuplicated(attrs$area_id), setequal(attrs$area_id, areas$area_id))
areas_check <- dplyr::left_join(areas[, "area_id"], attrs, by = "area_id")
stopifnot(nrow(areas_check) == nrow(areas),
          isTRUE(all.equal(areas_check$pm25, areas$pm25)))

# 7. Draw the grid -------------------------------------------------------------
p_grid <- ggplot2::ggplot(areas) +
  ggplot2::geom_sf(fill = "grey95", colour = cesgen_blue[["mid"]], linewidth = 0.2) +
  ggplot2::labs(title = "The simulated 14 x 14 grid of small areas",
                subtitle = "EPSG:27700, cells of 1 km x 1 km",
                caption = sim_caption()) +
  theme_cesgen()
ggplot2::ggsave("output/L25_grid_map.png", p_grid, width = 6, height = 6, dpi = 150)
stopifnot(file.exists("output/L25_grid_map.png"))

# EXERCISE -----------------------------------------------------------------------
# Try this (10-20 minutes):
# 1. Print the EPSG code of areas and the unit of its coordinates (metres or degrees).
# 2. Transform areas to EPSG:4326 and report how many degrees wide the bounding box is.
# 3. Select the areas with population above 3500, draw them in the accent colour
#    over the full grid and save the figure as output/L25_exercise.png.
# Expected: EPSG 27700 in metres; a box a fraction of a degree wide; a map with the
# selected cells highlighted. Worked solution: lessons/solutions/L25_solution.R
