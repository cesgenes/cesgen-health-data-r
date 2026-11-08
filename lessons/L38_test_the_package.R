# =============================================================================
# Lesson 38: Tests, checks and responsibility
# Goal:     run the automated tests of the template package, validate a function
#           against simulated data with a KNOWN truth, see how many Monte Carlo
#           replications a test needs, and practise the "never write to the
#           user's files by default" rule.
# Inputs:   templates/mini_health_package (the riskkit template). Optional: the
#           PITS package, if installed.
# Outputs:  printed tables; output/L38_recovery_check.csv. Files written by the
#           demos go to tempdir() only.
# Packages: testthat and devtools (called with ::, guarded). Optional: PITS.
# Data:     SIMULATED for teaching purposes; no real people.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

dir.create("output", showWarnings = FALSE)
template_dir <- "templates/mini_health_package"
stopifnot(dir.exists(template_dir))

# Run the tests of a package folder and return a one-row summary
run_package_tests <- function(path) {
  if (!requireNamespace("devtools", quietly = TRUE) ||
      !requireNamespace("testthat", quietly = TRUE)) {
    message("devtools and testthat are needed: install.packages(c(\"devtools\", \"testthat\")).")
    return(NULL)
  }
  results <- as.data.frame(devtools::test(path, reporter = "silent"))
  data.frame(tests = nrow(results),
             expectations_passed = sum(results$passed),
             failed = sum(results$failed),
             errors = sum(results$error),
             stringsAsFactors = FALSE)
}

# -----------------------------------------------------------------------------
# 1. Run the tests of the template (on a copy, so the template stays untouched)
# -----------------------------------------------------------------------------
copy_template <- function() {
  root <- tempfile("template_copy_")
  dir.create(root)
  file.copy(template_dir, root, recursive = TRUE)
  file.path(root, "mini_health_package")
}
good_copy <- copy_template()
test_summary <- run_package_tests(good_copy)
if (!is.null(test_summary)) {
  cat("\nTests of the template package:\n")
  print(test_summary, row.names = FALSE)
  stopifnot(test_summary$failed == 0, test_summary$errors == 0)
}

# -----------------------------------------------------------------------------
# 2. Validation against a known truth: simulate, estimate, compare
# -----------------------------------------------------------------------------
# Load the package's function without installing the package
source(file.path(template_dir, "R", "risk.R"))

# Simulate a binary exposure and outcome with a KNOWN odds ratio
simulate_binary <- function(n, baseline_risk, true_or, exposed_share = 0.5) {
  exposed <- rbinom(n, size = 1, prob = exposed_share)
  odds <- baseline_risk / (1 - baseline_risk) * true_or^exposed
  outcome <- rbinom(n, size = 1, prob = odds / (1 + odds))
  data.frame(exposed = exposed, outcome = outcome)
}

# One replication: estimate the odds ratio and its Wald 95% interval
estimate_once <- function(n, baseline_risk, true_or) {
  d <- simulate_binary(n, baseline_risk, true_or)
  fit <- glm(outcome ~ exposed, data = d, family = binomial)
  ci <- confint.default(fit)["exposed", ]
  c(log_or = unname(coef(fit)["exposed"]), lower = ci[[1]], upper = ci[[2]])
}

set.seed(2026)
true_or <- 2
baseline_risk <- 0.10
n_rep <- 300
reps <- t(replicate(n_rep, estimate_once(n = 2000, baseline_risk = baseline_risk, true_or = true_or)))

recovery <- data.frame(
  truth_log_or = log(true_or),
  mean_estimate = mean(reps[, "log_or"]),
  bias = mean(reps[, "log_or"]) - log(true_or),
  coverage_95 = mean(reps[, "lower"] <= log(true_or) & reps[, "upper"] >= log(true_or)),
  n_replications = n_rep
)
cat("\nRecovery check (Simulated data for teaching purposes):\n")
print(round(recovery, 3), row.names = FALSE)
write.csv(recovery, "output/L38_recovery_check.csv", row.names = FALSE)

# The checks are loose on purpose: random numbers vary, so we use tolerances
stopifnot(abs(recovery$bias) < 0.05,
          recovery$coverage_95 > 0.90, recovery$coverage_95 < 0.99)

# The package function should reproduce the risk in the exposed group
d_big <- simulate_binary(n = 200000, baseline_risk = baseline_risk, true_or = true_or)
observed_risk_exposed <- mean(d_big$outcome[d_big$exposed == 1])
predicted_risk_exposed <- or_to_absolute_risk(true_or, baseline_risk)$risk
cat(sprintf("Observed risk in exposed: %.3f; predicted by the function: %.3f\n",
            observed_risk_exposed, predicted_risk_exposed))
stopifnot(abs(observed_risk_exposed - predicted_risk_exposed) < 0.01)

# -----------------------------------------------------------------------------
# 3. Why validation matters: a plausible bug that the check catches
# -----------------------------------------------------------------------------
# Treating the odds ratio as if it were a risk ratio is a classic mistake. It is
# nearly invisible when the outcome is rare and large when it is common.
buggy_absolute_risk <- function(or, baseline_risk) baseline_risk * or
common_baseline <- 0.30
d_common <- simulate_binary(n = 200000, baseline_risk = common_baseline, true_or = true_or)
observed_common <- mean(d_common$outcome[d_common$exposed == 1])
good_gap <- abs(or_to_absolute_risk(true_or, common_baseline)$risk - observed_common)
bug_gap <- abs(buggy_absolute_risk(true_or, common_baseline) - observed_common)
cat(sprintf("Gap to the simulated truth: package function %.3f, buggy version %.3f\n",
            good_gap, bug_gap))
stopifnot(good_gap < 0.01, bug_gap > 0.05)   # the check separates the two

# -----------------------------------------------------------------------------
# 4. Stochastic code: how many replications does a test need?
# -----------------------------------------------------------------------------
# The standard error of a Monte Carlo proportion is sqrt(p * (1 - p) / n_sim)
mc_error <- data.frame(n_sim = c(50, 100, 500, 1000, 5000))
mc_error$se_at_power_80 <- sqrt(0.8 * 0.2 / mc_error$n_sim)
mc_error$approx_95_halfwidth <- 1.96 * mc_error$se_at_power_80
cat("\nMonte Carlo error of an estimated power of 0.80:\n")
print(round(mc_error, 3), row.names = FALSE)
stopifnot(all(diff(mc_error$se_at_power_80) < 0))

# Tests with few replications can only check coarse properties (range, direction,
# reproducibility with a seed), never a precise power value.
if (requireNamespace("PITS", quietly = TRUE)) {
  r1 <- PITS::calculate_power(n_pre = 12, n_post = 12, baseline = 15, level_change = -3,
                              sigma = 2, rho = 0.4, n_sim = 30, seed = 1)
  r2 <- PITS::calculate_power(n_pre = 12, n_post = 12, baseline = 15, level_change = -3,
                              sigma = 2, rho = 0.4, n_sim = 30, seed = 1)
  cat("\nPITS: same seed, same result? ", identical(r1$power, r2$power), "\n")
  stopifnot(identical(r1$power, r2$power), r1$power >= 0, r1$power <= 1)
  # Pre-flight validation with a clear error (a real function of PITS)
  msg <- tryCatch(PITS::validate_params(24, 24, 15, -3, -1, 0.4),
                  error = function(e) conditionMessage(e))
  cat("validate_params() with a negative sigma says:", msg, "\n")
  cat("Label for a power of 0.70:", PITS::interpret_power(0.70), "\n")
} else {
  message("PITS is not installed: the optional PITS demo was skipped.")
}

# -----------------------------------------------------------------------------
# 5. Never write to the user's files by default
# -----------------------------------------------------------------------------
# Same design as PITS::export_results(): the folder has NO default
save_table <- function(x, dir) {
  if (missing(dir) || !is.character(dir) || length(dir) != 1L) {
    stop("`dir` must be supplied as a single folder path (for example tempdir()). ",
         "This function never writes to the working directory by default.",
         call. = FALSE)
  }
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  path <- file.path(dir, "table.csv")
  utils::write.csv(x, path, row.names = FALSE)
  invisible(path)
}
msg_no_dir <- tryCatch(save_table(recovery), error = function(e) conditionMessage(e))
cat("\nWithout `dir`:", msg_no_dir, "\n")
written <- save_table(recovery, dir = tempdir())
stopifnot(grepl("must be supplied", msg_no_dir), file.exists(written))
unlink(written)

# -----------------------------------------------------------------------------
# 6. The full check (slow, so it is off by default)
# -----------------------------------------------------------------------------
run_full_check <- FALSE   # set to TRUE to run R CMD check on a copy of the template
if (run_full_check && requireNamespace("devtools", quietly = TRUE)) {
  check_result <- devtools::check(good_copy, document = TRUE, quiet = TRUE,
                                  check_dir = tempdir())
  print(check_result)
}

# -----------------------------------------------------------------------------
# EXERCISE (Try this)
# -----------------------------------------------------------------------------
# Break the function on purpose, in the COPY of the template, and watch the tests
# catch it:
#   1. In `good_copy`, open R/risk.R and change `odds1 <- odds0 * or` to
#      `odds1 <- odds0 + or`.
#   2. Re-run run_package_tests(good_copy).
#   3. Fix the line and run the tests again.
# Expected result: failed > 0 with the bug, failed = 0 after the fix.
# A worked solution is in lessons/solutions/L38_solution.R.
