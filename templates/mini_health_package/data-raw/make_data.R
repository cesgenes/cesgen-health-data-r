# Build the example data set `riskkit_example`.
#
# SIMULATED for teaching purposes. No real people, no real patient data.
# Run once from the package root:  source("data-raw/make_data.R")
# It writes data/riskkit_example.rda (usethis::use_data() also sets
# `LazyData: true` in DESCRIPTION). After the first run, document the data set
# in R/data.R (see the roxygen block at the end of this file) and run
# devtools::document().

set.seed(2026)

n <- 400
baseline_risk <- 0.10   # risk in the unexposed group (assumption of the simulation)
true_or <- 2            # true odds ratio used to generate the data

exposed <- rbinom(n, size = 1, prob = 0.4)
odds <- baseline_risk / (1 - baseline_risk) * true_or^exposed
risk <- odds / (1 + odds)
outcome <- rbinom(n, size = 1, prob = risk)

riskkit_example <- data.frame(exposed = exposed, outcome = outcome)

# Basic sanity checks before saving
stopifnot(
  nrow(riskkit_example) == n,
  all(riskkit_example$exposed %in% 0:1),
  all(riskkit_example$outcome %in% 0:1),
  !anyNA(riskkit_example)
)

if (requireNamespace("usethis", quietly = TRUE)) {
  usethis::use_data(riskkit_example, overwrite = TRUE)
} else {
  dir.create("data", showWarnings = FALSE)
  save(riskkit_example, file = file.path("data", "riskkit_example.rda"),
       compress = "bzip2")
}

# Roxygen block to paste into R/data.R after the first run:
#
# #' Simulated exposure and outcome (teaching data)
# #'
# #' 400 simulated records generated with a baseline risk of 0.10 and a true
# #' odds ratio of 2. No real people are described.
# #'
# #' @format A data frame with 400 rows and 2 variables:
# #' \describe{
# #'   \item{exposed}{Integer, 1 if exposed and 0 otherwise.}
# #'   \item{outcome}{Integer, 1 if the outcome occurred and 0 otherwise.}
# #' }
# #' @source Simulated in `data-raw/make_data.R`.
# "riskkit_example"
