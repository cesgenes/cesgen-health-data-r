# =============================================================================
# Lesson 13 - From genotype to risk: odds ratio, absolute risk, polygenic score
# Goal:     convert an odds ratio into an absolute risk, build a simple polygenic
#           score from weights, evaluate it, and state its limits.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv,
#           population_truth.csv  (SIMULATED population with known effects)
# Outputs:  console tables; output/L13_risk_by_score_decile.png
# Packages: readr, dplyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. Educational material; it does not replace
# a health professional.
# =============================================================================

source("R/helpers_general.R")

library(readr)
library(dplyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# A. The same odds ratio gives different absolute risks
# -----------------------------------------------------------------------------
stopifnot(abs(or_to_absolute_risk(2, 0.10) - 0.1818182) < 1e-6)   # 10 % baseline, OR 2 -> 18.2 %

risk_table <- expand.grid(
  baseline_risk = c(0.01, 0.05, 0.20),
  odds_ratio = c(1.2, 1.5, 2)
) %>%
  mutate(
    absolute_risk = or_to_absolute_risk(odds_ratio, baseline_risk),
    extra_risk_points = 100 * (absolute_risk - baseline_risk),   # percentage points
    risk_ratio = absolute_risk / baseline_risk
  ) %>%
  arrange(baseline_risk, odds_ratio)
print(risk_table, digits = 3)
# Reading: with a rare outcome the risk ratio is close to the odds ratio; with a common
# outcome the odds ratio overstates the risk ratio. The extra risk depends on the baseline.

# -----------------------------------------------------------------------------
# B. Data and a per-allele odds ratio for one SNP
# -----------------------------------------------------------------------------
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
truth <- read_csv("data-sim/out/population_truth.csv", show_col_types = FALSE)
dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)
stopifnot(identical(truth$snp, snp_cols))
cat("\nOverall frequency of the outcome (simulated):", round(mean(dat$disease), 3), "\n")

fit_logit <- function(snp, data) {
  d <- data.frame(disease = data$disease, x = data[[snp]])
  fit <- glm(disease ~ x, data = d, family = binomial)
  cbind(snp = snp, tidy_or(fit, "x"))
}
or_table <- do.call(rbind, lapply(snp_cols, fit_logit, data = dat)) %>% arrange(p_value)
print(head(or_table, 5), digits = 3)

top_snp <- or_table$snp[1]
or_per_copy <- or_table$or[1]
baseline_risk <- mean(dat$disease[dat[[top_snp]] == 0])   # risk in people with no copy
stopifnot(baseline_risk > 0, baseline_risk < 1)

absolute_by_copies <- data.frame(
  copies = 0:2,
  observed_risk = as.numeric(tapply(dat$disease, factor(dat[[top_snp]], levels = 0:2), mean)),
  model_risk = or_to_absolute_risk(or_per_copy^(0:2), baseline_risk)
)
cat("\nTop SNP:", top_snp, " odds ratio per copy:", round(or_per_copy, 2), "\n")
print(absolute_by_copies, digits = 3)

# -----------------------------------------------------------------------------
# C. A simple polygenic score: weights from one part of the data, evaluation in another
# -----------------------------------------------------------------------------
auc <- function(score, outcome) {
  n1 <- sum(outcome == 1)
  n0 <- sum(outcome == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  ranks <- rank(score)
  (sum(ranks[outcome == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# One logistic regression per SNP (as in a GWAS); the weight is the log odds ratio
estimate_weights <- function(data, snp_cols, p_threshold = 1) {
  fits <- lapply(snp_cols, function(s) {
    d <- data.frame(disease = data$disease, x = data[[s]])
    co <- summary(glm(disease ~ x, data = d, family = binomial))$coefficients
    c(beta = co["x", "Estimate"], p = co["x", "Pr(>|z|)"])
  })
  res <- do.call(rbind, fits)
  w <- res[, "beta"]
  w[res[, "p"] > p_threshold] <- 0     # keep only SNPs below the threshold
  names(w) <- snp_cols
  w
}

compute_prs <- function(data, snp_cols, weights) {
  as.vector(as.matrix(data[snp_cols]) %*% weights[snp_cols])
}

# Three roles: discovery (weights), calibration (turn the score into a probability), test
set.seed(13)
role <- sample(c("discovery", "calibration", "test"), nrow(dat), replace = TRUE, prob = c(0.5, 0.2, 0.3))
discovery <- dat[role == "discovery", ]
calibration <- dat[role == "calibration", ]
test <- dat[role == "test", ]
print(table(role))

prs_weights <- estimate_weights(discovery, snp_cols)
calibration$prs <- compute_prs(calibration, snp_cols, prs_weights)
test$prs <- compute_prs(test, snp_cols, prs_weights)

# Standardise with the calibration set, then calibrate to absolute risk
prs_mean <- mean(calibration$prs)
prs_sd <- sd(calibration$prs)
calibration$prs_z <- (calibration$prs - prs_mean) / prs_sd
test$prs_z <- (test$prs - prs_mean) / prs_sd

cal_fit <- glm(disease ~ prs_z, data = calibration, family = binomial)
test$risk <- predict(cal_fit, newdata = test, type = "response")

# How well does the score discriminate? Compare with the true weights (simulation only)
true_weights <- setNames(truth$beta, truth$snp)
prs_true <- compute_prs(test, snp_cols, true_weights)
cat("\nAUC on the test set - estimated weights:", round(auc(test$prs_z, test$disease), 3),
    " true weights:", round(auc(prs_true, test$disease), 3), "\n")
stopifnot(auc(test$prs_z, test$disease) > 0.5)

# Absolute risk by decile of the score
decile_table <- test %>%
  mutate(decile = ntile(prs_z, 10)) %>%
  group_by(decile) %>%
  summarise(n = n(), observed_risk = mean(disease), predicted_risk = mean(risk), .groups = "drop")
print(decile_table, digits = 3)

cat("\nMean predicted risk:", round(mean(test$risk), 3),
    " observed frequency:", round(mean(test$disease), 3), "\n")
top <- decile_table$observed_risk[decile_table$decile == 10]
bottom <- decile_table$observed_risk[decile_table$decile == 1]
cat("Observed risk in the top decile:", round(top, 3), " in the bottom decile:", round(bottom, 3),
    " risk ratio:", round(top / bottom, 1), " difference in percentage points:",
    round(100 * (top - bottom), 1), "\n")

p_dec <- ggplot(decile_table, aes(x = factor(decile), y = observed_risk)) +
  geom_col(fill = cesgen_blue[["light"]]) +
  geom_point(aes(y = predicted_risk), colour = cesgen_blue[["accent"]], size = 2.5) +
  labs(
    title = "Observed risk by decile of the polygenic score (simulated)",
    x = "Decile of the score (10 = highest)", y = "Observed frequency of the outcome",
    caption = sim_caption("Orange points: risk predicted from the calibrated score.")
  ) +
  theme_cesgen()
ggsave("output/L13_risk_by_score_decile.png", p_dec, width = 7, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# D. Limits to keep in mind (read, then check the numbers above)
# -----------------------------------------------------------------------------
# 1. The score ranks people within THIS population; it is not a diagnosis.
# 2. Absolute risk needs a baseline risk and a calibration set from a similar population.
# 3. Weights learned in one population may transfer unevenly to others (lesson 14).
# 4. Weights and evaluation must use different people (here: discovery vs test).

# =============================================================================
# EXERCISE (Try this) - about 20 minutes
# 1. With or_to_absolute_risk(), compute the absolute risk for an odds ratio of 1.3 when
#    the baseline risk is 2 % and when it is 30 %. Report the increase in percentage points.
# 2. Re-estimate the weights keeping only SNPs with p below 1, 0.5, 0.1 and 0.01
#    (argument p_threshold of estimate_weights()) and report the test AUC for each.
# Expected: about 0.6 percentage points for the 2 % baseline and about 5.8 for the 30 % baseline;
# four AUC values that do not differ greatly and none close to 1.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L13_solution.R
# =============================================================================
