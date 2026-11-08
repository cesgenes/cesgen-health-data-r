# =============================================================================
# Lesson 11 - Traits from several SNPs: build and check a prediction
# Goal:     combine several SNPs to predict a trait, measure the accuracy on data the
#           model has not seen, and compare with the known simulated truth.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv,
#           population_truth.csv  (SIMULATED population with known effects)
# Outputs:  console tables; output/L11_predicted_vs_observed.png
# Packages: readr, dplyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")

library(readr)
library(dplyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Data: genotypes as a matrix, trait and disease as vectors
# -----------------------------------------------------------------------------
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
truth <- read_csv("data-sim/out/population_truth.csv", show_col_types = FALSE)

dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)
stopifnot(identical(truth$snp, snp_cols))

x_all <- as.matrix(dat[snp_cols])
y_trait <- dat$trait
n <- nrow(dat)

# Helper functions for accuracy (out-of-sample R squared, RMSE, AUC)
r2_out <- function(observed, predicted) {
  1 - sum((observed - predicted)^2) / sum((observed - mean(observed))^2)
}
rmse <- function(observed, predicted) sqrt(mean((observed - predicted)^2))
auc <- function(score, outcome) {
  n1 <- sum(outcome == 1)
  n0 <- sum(outcome == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  ranks <- rank(score)
  (sum(ranks[outcome == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
stopifnot(abs(auc(c(0.1, 0.4, 0.35, 0.8), c(0, 0, 1, 1)) - 0.75) < 1e-12)

# -----------------------------------------------------------------------------
# 2. Split: 70 % to build the model, 30 % kept aside to test it
# -----------------------------------------------------------------------------
set.seed(11)
train_idx <- sample(n, size = round(0.7 * n))
test_idx <- setdiff(seq_len(n), train_idx)
stopifnot(length(intersect(train_idx, test_idx)) == 0, length(train_idx) + length(test_idx) == n)

# Fit a linear model on the selected SNPs (training rows) and score it on the test rows
fit_and_score <- function(sel, train_idx, test_idx, x, y) {
  train_df <- data.frame(y = y[train_idx], x[train_idx, sel, drop = FALSE])
  test_df <- data.frame(y = y[test_idx], x[test_idx, sel, drop = FALSE])
  fit <- lm(y ~ ., data = train_df)
  pred <- predict(fit, newdata = test_df)
  data.frame(
    n_snps = length(sel),
    r2_train = summary(fit)$r.squared,
    r2_test = r2_out(test_df$y, pred),
    rmse_test = rmse(test_df$y, pred)
  )
}

# Rank SNPs by their single-SNP p-value, computed on the TRAINING rows only
marginal_p <- function(idx, x, y) {
  apply(x[idx, , drop = FALSE], 2, function(snp_vec) {
    if (var(snp_vec) == 0) return(NA_real_)
    summary(lm(y[idx] ~ snp_vec))$coefficients[2, 4]
  })
}
p_train <- marginal_p(train_idx, x_all, y_trait)
ranked <- names(sort(p_train))

# -----------------------------------------------------------------------------
# 3. Compare models on the test rows
# -----------------------------------------------------------------------------
results <- rbind(
  cbind(model = "best single SNP", fit_and_score(ranked[1], train_idx, test_idx, x_all, y_trait)),
  cbind(model = "top 8 SNPs (chosen in training)", fit_and_score(ranked[1:8], train_idx, test_idx, x_all, y_trait)),
  cbind(model = "all 40 SNPs", fit_and_score(snp_cols, train_idx, test_idx, x_all, y_trait))
)

# Benchmark: the true genetic score (possible only because the data are simulated)
true_score <- as.vector(x_all %*% (4 * truth$beta))   # the generator multiplies the score by 4
r2_benchmark <- cor(true_score[test_idx], y_trait[test_idx])^2

cat("\nAccuracy on the test rows (R squared and RMSE):\n")
print(results, digits = 3)
cat("Benchmark with the TRUE genetic score (R squared, test rows):", round(r2_benchmark, 3), "\n")
stopifnot(all(results$r2_test <= 1), r2_benchmark > 0)

# Predicted against observed for the all-SNP model
fit_all <- lm(y ~ ., data = data.frame(y = y_trait[train_idx], x_all[train_idx, ]))
pred_test <- predict(fit_all, newdata = data.frame(x_all[test_idx, ]))
plot_df <- data.frame(observed = y_trait[test_idx], predicted = pred_test)

p_pred <- ggplot(plot_df, aes(x = predicted, y = observed)) +
  geom_point(alpha = 0.3, colour = cesgen_blue[["mid"]]) +
  geom_smooth(method = "lm", se = FALSE, colour = cesgen_blue[["accent"]]) +
  labs(
    title = "Test rows: observed trait against prediction (simulated)",
    x = "Predicted trait", y = "Observed trait",
    caption = sim_caption("Points far from a straight line show how much is not predicted.")
  ) +
  theme_cesgen()
ggsave("output/L11_predicted_vs_observed.png", p_pred, width = 6, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# 4. Which SNPs does the model flag, compared with the known truth?
# -----------------------------------------------------------------------------
p_all <- summary(fit_all)$coefficients[-1, 4]   # drop the intercept
recovery <- data.frame(snp = names(p_all), p_value = unname(p_all), stringsAsFactors = FALSE) %>%
  left_join(truth, by = "snp") %>%
  mutate(
    flag_nominal = p_value < 0.05,
    flag_bonferroni = p_value < bonferroni_threshold(length(p_all))
  )
cat("\nFlagged at p < 0.05 against truly causal:\n")
print(table(flagged = recovery$flag_nominal, truly_causal = recovery$causal))
cat("Flagged after Bonferroni correction against truly causal:\n")
print(table(flagged = recovery$flag_bonferroni, truly_causal = recovery$causal))
cat("Share of causal SNPs flagged at p < 0.05:", round(mean(recovery$flag_nominal[recovery$causal]), 2), "\n")
cat("Non-causal SNPs flagged at p < 0.05:", sum(recovery$flag_nominal & !recovery$causal), "of",
    sum(!recovery$causal), "\n")
stopifnot(nrow(recovery) == 40)

# -----------------------------------------------------------------------------
# 5. Same idea for a yes/no outcome: logistic model and AUC
# -----------------------------------------------------------------------------
disease <- dat$disease
fit_glm <- glm(
  disease ~ .,
  data = data.frame(disease = disease[train_idx], x_all[train_idx, ]),
  family = binomial
)
risk_test <- predict(fit_glm, newdata = data.frame(x_all[test_idx, ]), type = "response")
auc_model <- auc(risk_test, disease[test_idx])
true_liability <- as.vector(x_all %*% truth$beta)
auc_benchmark <- auc(true_liability[test_idx], disease[test_idx])
cat("\nAUC on the test rows - fitted model:", round(auc_model, 3),
    " true genetic score:", round(auc_benchmark, 3), "\n")
stopifnot(auc_model > 0.5, auc_benchmark > 0.5)

# -----------------------------------------------------------------------------
# 6. The classic mistake: choosing SNPs with ALL rows, then "testing" on some of them
#    Here the predictors are pure noise, so the honest test R squared is about zero or below.
# -----------------------------------------------------------------------------
set.seed(111)
noise <- matrix(
  rbinom(n * 300, 2, 0.3), nrow = n, ncol = 300,
  dimnames = list(NULL, sprintf("noise%03d", 1:300))
)
cors_all <- abs(as.vector(cor(noise, y_trait)))                          # uses every row (leak)
cors_train <- abs(as.vector(cor(noise[train_idx, ], y_trait[train_idx])))  # training rows only
sel_leaky <- colnames(noise)[order(cors_all, decreasing = TRUE)[1:20]]
sel_honest <- colnames(noise)[order(cors_train, decreasing = TRUE)[1:20]]

all_idx <- seq_len(n)
leak_table <- rbind(
  cbind(selection = "no split (choose, fit and evaluate on all rows)",
        fit_and_score(sel_leaky, all_idx, all_idx, noise, y_trait)),
  cbind(selection = "leaky (all rows used to choose, then split)",
        fit_and_score(sel_leaky, train_idx, test_idx, noise, y_trait)),
  cbind(selection = "honest (training rows only)",
        fit_and_score(sel_honest, train_idx, test_idx, noise, y_trait))
)
cat("\nPure-noise predictors: R squared with no split, with the leak and without it\n")
print(leak_table, digits = 3)
# Expected pattern: the 'no split' row looks clearly positive although the predictors are noise;
# the leaky row is better than the honest one; the honest row is about zero or negative.

# =============================================================================
# EXERCISE (Try this) - about 20 minutes
# 1. Change the training fraction from 0.7 to 0.3 and re-run sections 2 and 3.
#    Report the test R squared of the all-SNP model.
# 2. Repeat the split with five different seeds (for example 1 to 5) for both fractions
#    and summarise the test R squared (mean and range).
# Expected: with the smaller training set the test R squared is lower and varies more
# from seed to seed; the benchmark with the true score does not change with the seed.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L11_solution.R
# =============================================================================
