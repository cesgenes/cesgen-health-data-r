# Extra simulated data for module 4 (lessons 24-30).
# Source from the repository root:  source("data-sim/extra_4.R")
# The main generator (00_generate_all.R) already creates the small-area layer
# (areas_sim.gpkg and areas_sim_attributes.csv). This file adds:
#   - ensure_areas_data(): makes sure the spatial files exist (needs the sf package)
#   - ensure_extra_4_data(): creates patients_areas_sim.csv, one row per simulated case,
#     with its area, sex, age group and admission month (used in lesson 28)
# Everything is invented for teaching purposes. A fixed seed makes the output reproducible.

ensure_areas_data <- function(dir = "data-sim/out") {
  gpkg <- file.path(dir, "areas_sim.gpkg")
  csv <- file.path(dir, "areas_sim_attributes.csv")
  if (!(file.exists(gpkg) && file.exists(csv))) {
    message("Generating the simulated small areas ...")
    source("data-sim/00_generate_all.R", local = new.env())
  }
  if (!(file.exists(gpkg) && file.exists(csv))) {
    stop("Spatial files not found. Install the 'sf' package and run ",
         "source('data-sim/00_generate_all.R') from the repository root.")
  }
  invisible(dir)
}

ensure_extra_4_data <- function(dir = "data-sim/out", seed = 2027) {
  ensure_areas_data(dir)
  target <- file.path(dir, "patients_areas_sim.csv")
  if (file.exists(target)) return(invisible(target))
  attrs <- read.csv(file.path(dir, "areas_sim_attributes.csv"), stringsAsFactors = FALSE)
  set.seed(seed)
  # one row per simulated case, so the row counts per area match the 'cases' column
  area_id <- sample(rep(attrs$area_id, times = attrs$cases))
  n <- length(area_id)
  patients <- data.frame(
    patient_id = sprintf("P%05d", seq_len(n)),
    area_id = area_id,
    sex = sample(c("F", "M"), n, replace = TRUE),
    age_group = sample(c("0-17", "18-39", "40-64", "65+"), n, replace = TRUE,
                       prob = c(0.10, 0.25, 0.35, 0.30)),
    admission_month = sample(1:12, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
  stopifnot(nrow(patients) == sum(attrs$cases))
  write.csv(patients, target, row.names = FALSE)
  invisible(target)
}
