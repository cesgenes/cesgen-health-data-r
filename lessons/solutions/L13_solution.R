# =============================================================================
# Lesson 13 - Worked solution
# Task:     (1) absolute risk for an odds ratio of 1.3 at two baselines;
#           (2) test AUC of the polygenic score for four p-value thresholds.
# Inputs:   data-sim/out/population_*.csv  (SIMULATED)
# Outputs:  console only
# Packages: readr, dplyr
# Run from the repository root. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
library(readr)
library(dplyr)
ensure_sim_data()

# Task 1 -------------------------------------------------------------------
baselines <- c(0.02, 0.30)
absolute <- or_to_absolute_risk(1.3, baselines)
task1 <- data.frame(baseline_risk = baselines, absolute_risk = absolute,
                    increase_points = 100 * (absolute - baselines))
print(task1, digits = 3)
stopifnot(abs(task1$increase_points[1] - 0.58) < 0.01, abs(task1$increase_points[2] - 5.78) < 0.01)
# Same odds ratio, about ten times more extra risk (in percentage points) when the baseline is higher.

# Task 2 -------------------------------------------------------------------
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)

auc <- function(score, outcome) {
  n1 <- sum(outcome == 1)
  n0 <- sum(outcome == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  ranks <- rank(score)
  (sum(ranks[outcome == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

estimate_weights <- function(data, snp_cols, p_threshold = 1) {
  fits <- lapply(snp_cols, function(s) {
    d <- data.frame(disease = data$disease, x = data[[s]])
    co <- summary(glm(disease ~ x, data = d, family = binomial))$coefficients
    c(beta = co["x", "Estimate"], p = co["x", "Pr(>|z|)"])
  })
  res <- do.call(rbind, fits)
  w <- res[, "beta"]
  w[res[, "p"] > p_threshold] <- 0
  names(w) <- snp_cols
  w
}

compute_prs <- function(data, snp_cols, weights) {
  as.vector(as.matrix(data[snp_cols]) %*% weights[snp_cols])
}

set.seed(13)
role <- sample(c("discovery", "calibration", "test"), nrow(dat), replace = TRUE, prob = c(0.5, 0.2, 0.3))
discovery <- dat[role == "discovery", ]
test <- dat[role == "test", ]

thresholds <- c(1, 0.5, 0.1, 0.01)
task2 <- data.frame(p_threshold = thresholds, n_snps_used = NA_integer_, test_auc = NA_real_)
for (i in seq_along(thresholds)) {
  w <- estimate_weights(discovery, snp_cols, p_threshold = thresholds[i])
  task2$n_snps_used[i] <- sum(w != 0)
  task2$test_auc[i] <- auc(compute_prs(test, snp_cols, w), test$disease)
}
print(task2, digits = 3)
stopifnot(all(task2$test_auc > 0.5), all(task2$test_auc < 1))
# Reading: a stricter threshold uses fewer SNPs; the AUC changes by a small amount here because
# the simulated effects are spread over several SNPs. The right threshold is itself chosen on data
# that must not be the test set.
