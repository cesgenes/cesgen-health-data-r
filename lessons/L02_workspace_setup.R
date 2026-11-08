# =============================================================================
# Lesson 2 - Your R workspace: projects, scripts and packages
# Goal:     Check that your project, folders and packages are ready for the course.
# Inputs:   none (the script only looks at the repository folders and at R itself)
# Outputs:  a readiness report on screen and output/l02_package_report.csv
# Packages: none needed to start; the script checks which course packages are installed
# Run from the repository root (open the folder as an RStudio project first).
# Simulated data for teaching purposes: nothing here comes from real people.
# =============================================================================

# 1. Where am I? A project makes the repository folder the working directory -----
cat("R version:", R.version.string, "\n")
cat("Working directory (folder name only):", basename(getwd()), "\n")

# The native pipe |> used in later lessons needs R 4.1.0 or later
r_ok <- getRversion() >= "4.1.0"
cat("R 4.1.0 or later:", r_ok, "\n")

# The course scripts use relative paths, so these folders must be visible from here
required_paths <- c("R", "data-sim", "lessons")
paths_ok <- dir.exists(required_paths)
names(paths_ok) <- required_paths
print(paths_ok)
if (!all(paths_ok)) {
  stop("Open the repository as an RStudio project (or use setwd() to go to its root).")
}

# 2. Scripts: a script is a text file of R commands that run from top to bottom -----
# Lines that start with # are comments: R ignores them, people read them.
source("R/helpers_general.R")   # loads the course helper functions
ensure_sim_data()               # creates data-sim/out/ the first time, then does nothing

# 3. Packages: install ONCE per computer, load in EVERY session -------------------
# install.packages("dplyr")     # once per computer (do not run it from a script)
# library(dplyr)                # at the start of every R session
course_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "stringr", "lubridate", "purrr",
                     "broom", "meta", "sf", "spdep", "spatialreg", "DBI", "duckdb",
                     "knitr", "rmarkdown")
module_1_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "stringr")

installed <- vapply(course_packages, requireNamespace, logical(1), quietly = TRUE)
report <- data.frame(
  package = course_packages,
  installed = unname(installed),
  needed_in_module_1 = course_packages %in% module_1_packages,
  stringsAsFactors = FALSE
)
print(report, row.names = FALSE)

missing_now <- report$package[report$needed_in_module_1 & !report$installed]
if (length(missing_now) > 0) {
  cat("\nInstall the missing packages ONCE by typing this in the console:\n")
  cat("install.packages(c(", paste0('"', missing_now, '"', collapse = ", "), "))\n", sep = "")
} else {
  cat("\nAll the packages needed for module 1 are installed.\n")
}

# 4. Use what you have: read a small simulated table with base R ------------------
patients <- read.csv("data-sim/out/patients_clean.csv", stringsAsFactors = FALSE)
cat("Rows in patients_clean.csv:", nrow(patients), "\n")
print(head(patients, 3))

# 5. Save the report in output/ (a folder for results, apart from data and code) ----
dir.create("output", showWarnings = FALSE)
write.csv(report, "output/l02_package_report.csv", row.names = FALSE)

# 6. Sanity checks ----------------------------------------------------------------
stopifnot(
  nrow(report) == length(course_packages),
  file.exists("output/l02_package_report.csv"),
  nrow(patients) > 0,
  all(c("patient_id", "sex", "age") %in% names(patients))
)
cat("\nLesson 2 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Open the repository folder as an RStudio project (File > New Project >
#    Existing Directory), open this script and run it with the Source button.
# 2. If the table above shows installed = FALSE for any module 1 package, copy the
#    install.packages(...) line printed by the script into the console, run it
#    once, and then run this script again. All five module 1 packages should show TRUE.
# 3. Add a block at the end that writes your R version and today's date to
#    output/l02_session_note.txt with writeLines(), and check that the file exists.
# Expected result: a package table with TRUE for the five module 1 packages and
# a text file with two lines. A worked solution is in lessons/solutions/L02_solution.R
# =============================================================================
