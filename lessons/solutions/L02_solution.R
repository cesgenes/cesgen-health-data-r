# =============================================================================
# Lesson 2 - Worked solution of the exercise
# Goal:     Check packages with a reusable function and write a session note.
# Inputs:   none
# Outputs:  output/l02_session_note.txt
# Packages: none (base R only)
# Run from the repository root.
# =============================================================================

source("R/helpers_general.R")

# 1. A reusable function: which of these packages are not installed? ---------------
missing_packages <- function(packages) {
  is_installed <- vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  packages[!is_installed]
}

module_1_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "stringr")
to_install <- missing_packages(module_1_packages)
if (length(to_install) > 0) {
  cat("Run this once in the console:\n")
  cat("install.packages(c(", paste0('"', to_install, '"', collapse = ", "), "))\n", sep = "")
} else {
  cat("Module 1 packages are all installed.\n")
}

# 2. Write a session note: R version and today's date -------------------------------
dir.create("output", showWarnings = FALSE)
note <- c(paste("R version:", R.version.string),
          paste("Date:", format(Sys.Date(), "%Y-%m-%d")))
writeLines(note, "output/l02_session_note.txt")

# 3. Sanity checks -------------------------------------------------------------------
stopifnot(
  is.character(to_install),
  file.exists("output/l02_session_note.txt"),
  length(readLines("output/l02_session_note.txt")) == 2
)
cat("Solution for lesson 2 ran correctly.\n")
