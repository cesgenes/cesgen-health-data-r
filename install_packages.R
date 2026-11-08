# Installs the packages used in the course. Run once from the repository root:
#   source("install_packages.R")
# Optional: use renv for a locked, reproducible library:
#   install.packages("renv"); renv::init(); source("install_packages.R"); renv::snapshot()

pkgs <- c(
  # core tidyverse pieces
  "readr", "dplyr", "tidyr", "ggplot2", "stringr", "lubridate", "purrr", "tibble",
  # statistics and meta-analysis
  "broom", "meta",
  # spatial analysis
  "sf", "spdep", "spatialreg",
  # databases
  "DBI", "duckdb",
  # reporting
  "knitr", "rmarkdown", "quarto",
  # tests and package development (module 6)
  "testthat", "devtools", "usethis", "roxygen2"
)
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)
message("Course packages ready. Missing now: ", paste(setdiff(pkgs, rownames(installed.packages())), collapse = ", "))
