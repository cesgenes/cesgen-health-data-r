# =============================================================================
# Lesson 20: Phenotype-wide association studies (PheWAS) - why multiple testing matters
# Goal:     show with simulated NULL tests (no true effect anywhere) how many
#           "significant" results appear by chance, and how Bonferroni and
#           Benjamini-Hochberg corrections change that. Also show the price of
#           correcting: lower power for a real effect.
# Inputs:   none (everything is simulated in the script)
# Outputs:  printed tables; output/L20_false_positives.png, output/L20_familywise_error.png
# Packages: dplyr, ggplot2
# Data:     Simulated data for teaching purposes. Runs in well under a minute.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(dplyr)
library(ggplot2)

source("R/helpers_general.R")
dir.create("output", showWarnings = FALSE)
set.seed(2026)

n_patients <- 1000    # patients in each simulated study
n_tests    <- 40      # phenotypes tested (as in the course EHR)
n_reps     <- 200     # number of simulated studies
alpha      <- 0.05

# -----------------------------------------------------------------------------
# 1. Theory first: the chance of at least one false positive among m independent tests
# -----------------------------------------------------------------------------
theory <- tibble(m = c(1, 5, 10, 20, 40, 100, 1000)) %>%
  mutate(p_at_least_one_false_positive = round(1 - (1 - alpha)^m, 3),
         bonferroni_threshold = alpha / m)
cat("Chance of at least one false positive at alpha = 0.05 (independent tests):\n")
print(theory)

# -----------------------------------------------------------------------------
# 2. One simulated null study: the outcome is unrelated to every phenotype
# -----------------------------------------------------------------------------
one_null_study <- function(n_patients, n_tests) {
  outcome <- rbinom(n_patients, 1, 0.07)          # adverse event, about 7% of patients
  prevalence <- runif(n_tests, 0.05, 0.30)        # phenotypes of moderate frequency
  vapply(seq_len(n_tests), function(j) {
    exposure <- rbinom(n_patients, 1, prevalence[j])
    fit <- suppressWarnings(glm(outcome ~ exposure, family = binomial()))
    summary(fit)$coefficients["exposure", "Pr(>|z|)"]
  }, numeric(1))
}

# -----------------------------------------------------------------------------
# 3. Repeat it many times: each column is one study, each row one phenotype test
# -----------------------------------------------------------------------------
all_p <- replicate(n_reps, one_null_study(n_patients, n_tests))
stopifnot(nrow(all_p) == n_tests, ncol(all_p) == n_reps, all(all_p >= 0 & all_p <= 1))

false_positives <- tibble(
  unadjusted = colSums(all_p < alpha),
  bonferroni = apply(all_p, 2, function(p) sum(p.adjust(p, method = "bonferroni") < alpha)),
  bh         = apply(all_p, 2, function(p) sum(p.adjust(p, method = "BH") < alpha))
)

summary_table <- tibble(
  method = c("No correction (p < 0.05)", "Bonferroni", "Benjamini-Hochberg (FDR 5%)"),
  mean_false_positives_per_study = round(colMeans(false_positives), 2),
  studies_with_at_least_one = round(colMeans(false_positives >= 1), 3)
)
cat("\nResults over", n_reps, "simulated null studies of", n_tests, "tests each:\n")
print(summary_table)
cat("Expected without correction: about", alpha * n_tests, "false positives per study,",
    "and", round(1 - (1 - alpha)^n_tests, 3), "of studies with at least one.\n")

# -----------------------------------------------------------------------------
# 4. Plots
# -----------------------------------------------------------------------------
p_hist <- ggplot(false_positives, aes(x = unadjusted)) +
  geom_bar(fill = cesgen_blue[["mid"]]) +
  labs(title = "Chance findings with no correction",
       subtitle = "Each bar: simulated studies with that many 'significant' phenotypes (no real effect exists)",
       x = "Phenotypes with p < 0.05 in one study", y = "Number of simulated studies",
       caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L20_false_positives.png", p_hist, width = 7, height = 4, dpi = 150)

p_fwer <- ggplot(theory, aes(x = m, y = p_at_least_one_false_positive)) +
  geom_line(colour = cesgen_blue[["dark"]]) +
  geom_point(colour = cesgen_blue[["accent"]], size = 2.5) +
  scale_x_log10() +
  labs(title = "More tests, more chance findings",
       x = "Number of independent tests (log scale)",
       y = "Chance of at least one false positive", caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L20_familywise_error.png", p_fwer, width = 6, height = 4, dpi = 150)

# -----------------------------------------------------------------------------
# 5. The price of correction: power for one real effect (odds ratio 1.8)
# -----------------------------------------------------------------------------
one_true_study <- function(n_patients, prevalence, odds_ratio, baseline_risk = 0.05) {
  exposure <- rbinom(n_patients, 1, prevalence)
  outcome <- rbinom(n_patients, 1, plogis(qlogis(baseline_risk) + log(odds_ratio) * exposure))
  fit <- suppressWarnings(glm(outcome ~ exposure, family = binomial()))
  summary(fit)$coefficients["exposure", "Pr(>|z|)"]
}
p_true <- replicate(n_reps, one_true_study(n_patients, prevalence = 0.25, odds_ratio = 1.8))
power_table <- tibble(
  threshold = c("p < 0.05", paste0("p < ", signif(alpha / n_tests, 2), " (Bonferroni for ", n_tests, " tests)")),
  power = c(mean(p_true < alpha), mean(p_true < alpha / n_tests))
)
cat("\nPower to detect a real odds ratio of 1.8 (exposure in 25% of patients):\n")
print(power_table)
# A stricter threshold protects against false positives and costs power.

stopifnot(file.exists("output/L20_false_positives.png"),
          file.exists("output/L20_familywise_error.png"),
          power_table$power[2] <= power_table$power[1])
cat("\nL20 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Set n_tests <- 100 and run the script again.
# 2. Read the summary table: what share of studies has at least one false
#    positive without correction, with Bonferroni and with Benjamini-Hochberg?
# 3. Compare with the theory table row for m = 100.
# Expected: without correction, almost every study (about 99%) has at least one
# false positive; with Bonferroni or Benjamini-Hochberg about 5% or fewer.
# Worked solution: lessons/solutions/L20_solution.R
# =============================================================================
