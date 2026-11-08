# Installs the packages used in the course. Run once from the repository root:
#   source("install_packages.R")
# This installs the latest CRAN versions, so results can differ slightly from the versions used to
# verify the course (R 4.6.1; see CHECKLOG.md). To install exactly those versions, use the
# lockfile instead:  install.packages("renv"); renv::restore()

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
