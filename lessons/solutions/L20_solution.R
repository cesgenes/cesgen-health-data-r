# Solution for lesson 20 (run from the repository root).
# Same simulation as L20_multiple_testing_sim.R, with 100 tests.
library(dplyr)

source("R/helpers_general.R")
set.seed(2026)

n_patients <- 1000
n_tests <- 100
n_reps <- 200
alpha <- 0.05

one_null_study <- function(n_patients, n_tests) {
  outcome <- rbinom(n_patients, 1, 0.07)
  prevalence <- runif(n_tests, 0.05, 0.30)
  vapply(seq_len(n_tests), function(j) {
    exposure <- rbinom(n_patients, 1, prevalence[j])
    fit <- suppressWarnings(glm(outcome ~ exposure, family = binomial()))
    summary(fit)$coefficients["exposure", "Pr(>|z|)"]
  }, numeric(1))
}

all_p <- replicate(n_reps, one_null_study(n_patients, n_tests))
share_any <- c(
  unadjusted = mean(colSums(all_p < alpha) >= 1),
  bonferroni = mean(apply(all_p, 2, function(p) any(p.adjust(p, "bonferroni") < alpha))),
  bh = mean(apply(all_p, 2, function(p) any(p.adjust(p, "BH") < alpha)))
)
print(round(share_any, 3))

theory_100 <- 1 - (1 - alpha)^n_tests
cat("Theory for m = 100:", round(theory_100, 3), "\n")

stopifnot(share_any[["unadjusted"]] > 0.9, share_any[["bonferroni"]] < 0.15, share_any[["bh"]] < 0.15)
