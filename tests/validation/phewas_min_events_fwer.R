# Validation script (not part of the automatic tests; it takes about a minute).
# Question: does the minimum-events rule of run_phewas() change the family-wise error of the
# Bonferroni correction when it is applied over the tests that were actually run?
# Setting: a null PheWAS (no phenotype is related to the outcome), 1,000 patients, 40 phenotypes
# with prevalences from 0.5 to 30 percent, 250 studies per setting.
# Run from the repository root:  Rscript tests/validation/phewas_min_events_fwer.R
# Result on 2026-11-08 (R 4.6.1): FWER 0.044 (no rule), 0.052 (1), 0.048 (3), 0.052 (5), 0.076 (10);
# the standard error of each value is about 0.014.
set.seed(2026)
one_study <- function(min_events, n = 1000, m = 40) {
  y <- rbinom(n, 1, 0.07)
  prevalence <- runif(m, 0.005, 0.30)
  p <- vapply(prevalence, function(pr) {
    x <- rbinom(n, 1, pr)
    cells <- c(sum(x == 1 & y == 1), sum(x == 1 & y == 0), sum(x == 0 & y == 1), sum(x == 0 & y == 0))
    if (sum(x) < 10 || min(cells) < min_events) return(NA_real_)
    summary(suppressWarnings(glm(y ~ x, family = binomial())))$coefficients[2, 4]
  }, numeric(1))
  k <- sum(!is.na(p))
  if (k == 0) return(c(any = 0, k = 0))
  c(any = any(p < 0.05 / k, na.rm = TRUE), k = k)
}
for (min_events in c(0, 1, 3, 5, 10)) {
  r <- replicate(250, one_study(min_events))
  cat(sprintf("min_events %2d: tests run %4.1f, family-wise error %.3f\n",
              min_events, mean(r["k", ]), mean(r["any", ])))
}
