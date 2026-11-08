# Lesson 32 - Bias and equity: auditing a result, and the traps of analysing the same data twice
# Goal:     (1) check who is represented and audit a genetic score by group;
#           (2) see measurement bias in a small planted example;
#           (3) show with a simulation that selecting variables on ALL the data inflates the
#               apparent performance ("double-dipping"), and how train/validation/evaluation
#               partitions give an honest figure.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv
#           (population_truth.csv is only used at the end to check the selection)
# Outputs:  output/L32_representation.png, output/L32_audit_auc_by_group.png,
#           output/L32_double_dipping.png and small tables printed to the console
# Packages: dplyr, tidyr, ggplot2
# Run from the repository root. Simulated data for teaching purposes. The labels G1-G3 are
# labels of simulated groups, not real populations.
# Educational material; it does not replace a health professional.

source("R/helpers_general.R")          # theme_cesgen(), sim_caption(), cesgen_blue
library(dplyr)
library(tidyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# ---- 0. Helper functions used below -------------------------------------------------------
# Area under the ROC curve from ranks (Mann-Whitney): 0.5 = no discrimination, 1 = perfect.
auc_rank <- function(score, outcome) {
  ok <- !is.na(score) & !is.na(outcome)
  score <- score[ok]
  outcome <- outcome[ok]
  n1 <- sum(outcome == 1)
  n0 <- sum(outcome == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(score)
  (sum(r[outcome == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# ---- 1. Representation: who is in the data? -----------------------------------------------
pheno <- read.csv("data-sim/out/population_pheno.csv", stringsAsFactors = FALSE)
geno <- read.csv("data-sim/out/population_genotypes.csv", stringsAsFactors = FALSE)
stopifnot(identical(pheno$patient_id, geno$patient_id))
snp_cols <- grep("^snp", names(geno), value = TRUE)

rep_tab <- pheno %>%
  count(group) %>%
  mutate(share = round(n / sum(n), 3))
print(rep_tab)

p_rep <- ggplot(rep_tab, aes(group, share)) +
  geom_col(fill = cesgen_blue[["mid"]]) +
  geom_text(aes(label = paste0(round(100 * share), "%")), vjust = -0.4) +
  labs(title = "Share of each simulated group in the data",
       x = "Simulated group", y = "Share of participants",
       caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L32_representation.png", p_rep, width = 6, height = 4, dpi = 150)

# ---- 2. Build a simple score on a training part and audit it on a held-out test part --------
dat <- cbind(pheno, geno[, snp_cols])
set.seed(32)
train_rows <- sample(nrow(dat), round(0.7 * nrow(dat)))
dat$part <- ifelse(seq_len(nrow(dat)) %in% train_rows, "train", "test")

# One regression per SNP, using ONLY the training rows (selection is part of the model)
scan_snps <- function(g_mat, y) {
  res <- t(apply(g_mat, 2, function(g) {
    co <- summary(lm(y ~ g))$coefficients
    if (!"g" %in% rownames(co)) return(c(beta = NA_real_, p_value = NA_real_))
    c(beta = co["g", "Estimate"], p_value = co["g", "Pr(>|t|)"])
  }))
  res <- as.data.frame(res)
  res$snp <- rownames(res)
  res
}
train <- dat[dat$part == "train", ]
snp_scan <- scan_snps(as.matrix(train[, snp_cols]), train$trait)
selected <- !is.na(snp_scan$p_value) & snp_scan$p_value < 0.01
stopifnot(sum(selected) >= 1)
message("SNPs selected on the training part: ", sum(selected))

# Score = weighted sum of the selected SNPs; then a logistic model turns it into a risk
dat$score <- as.numeric(as.matrix(dat[, snp_scan$snp[selected]]) %*% snp_scan$beta[selected])
fit_risk <- glm(disease ~ score, data = dat[dat$part == "train", ], family = binomial)
dat$risk <- predict(fit_risk, newdata = dat, type = "response")
threshold <- unname(quantile(dat$score[dat$part == "train"], 0.8))   # flag the top 20%

# Performance by group with a bootstrap interval, on the test part only
audit_by_group <- function(df, group_col, outcome_col, score_col, risk_col, threshold,
                           n_boot = 200) {
  groups <- sort(unique(df[[group_col]]))
  rows <- lapply(groups, function(g) {
    d <- df[df[[group_col]] == g, ]
    y <- d[[outcome_col]]
    s <- d[[score_col]]
    boots <- replicate(n_boot, {
      i <- sample(nrow(d), replace = TRUE)
      auc_rank(s[i], y[i])
    })
    data.frame(group = g, n = nrow(d), events = sum(y),
               auc = auc_rank(s, y),
               auc_low = unname(quantile(boots, 0.025, na.rm = TRUE)),
               auc_high = unname(quantile(boots, 0.975, na.rm = TRUE)),
               mean_predicted = mean(d[[risk_col]]), observed = mean(y),
               share_flagged = mean(s >= threshold),
               sensitivity = mean(s[y == 1] >= threshold))
  })
  do.call(rbind, rows)
}
test <- dat[dat$part == "test", ]
test$everyone <- "All"
set.seed(33)
audit <- rbind(audit_by_group(test, "everyone", "disease", "score", "risk", threshold),
               audit_by_group(test, "group", "disease", "score", "risk", threshold))
audit[, -1] <- round(audit[, -1], 3)
print(audit)
stopifnot(all(audit$auc >= 0 & audit$auc <= 1, na.rm = TRUE))
stopifnot(sum(audit$n[audit$group != "All"]) == nrow(test))

# Read the table with the sample size in mind: a small group has few events and a wide
# interval. The audit cannot confirm equal performance, and it cannot confirm a gap either.
p_audit <- ggplot(audit, aes(group, auc)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = cesgen_blue[["grey"]]) +
  geom_pointrange(aes(ymin = auc_low, ymax = auc_high), colour = cesgen_blue[["dark"]]) +
  labs(title = "Discrimination of the score by simulated group (test part)",
       x = "Simulated group", y = "AUC with 95% bootstrap interval",
       caption = sim_caption("Dashed line: no discrimination (AUC = 0.5).")) +
  theme_cesgen()
ggsave("output/L32_audit_auc_by_group.png", p_audit, width = 6.5, height = 4, dpi = 150)

# Check the selection against the planted truth (only possible because the data are simulated)
truth <- read.csv("data-sim/out/population_truth.csv", stringsAsFactors = FALSE)
true_causal <- truth$snp[truth$causal]
message("Selected SNPs that are truly causal: ",
        sum(snp_scan$snp[selected] %in% true_causal), " of ", sum(selected))

# ---- 3. Measurement bias: a planted example -------------------------------------------------
# Imagine the trait is read by a device that over-reads by 3 units in group G3.
# In real work you do not know the true value: you detect this by comparing with a
# reference method, by group.
set.seed(34)
dat$trait_measured <- dat$trait + ifelse(dat$group == "G3", 3, 0) + rnorm(nrow(dat), 0, 0.5)
cut_true <- unname(quantile(dat$trait, 0.9))
cut_measured <- unname(quantile(dat$trait_measured, 0.9))
meas_tab <- dat %>%
  group_by(group) %>%
  summarise(n = n(),
            mean_error = mean(trait_measured - trait),
            flagged_true = mean(trait > cut_true),
            flagged_measured = mean(trait_measured > cut_measured),
            .groups = "drop")
print(meas_tab)
stopifnot(meas_tab$mean_error[meas_tab$group == "G3"] > 2)
stopifnot(abs(meas_tab$mean_error[meas_tab$group == "G1"]) < 0.2)

# ---- 4. Double-dipping: a simulation with pure noise ------------------------------------------
# Outcome and features are random, so any real performance must be 0.5 (AUC).
pick_features <- function(x_sel, y_sel, k) {
  r <- as.numeric(cor(x_sel, y_sel))
  top <- order(abs(r), decreasing = TRUE)[seq_len(k)]
  list(index = top, sign = sign(r[top]))
}
make_score <- function(x_new, sel) {
  as.numeric(x_new[, sel$index, drop = FALSE] %*% sel$sign)
}
simulate_double_dip <- function(n = 200, p = 500, k = 20) {
  x <- matrix(rnorm(n * p), nrow = n, ncol = p)
  y <- rbinom(n, 1, 0.5)
  # WRONG: choose the features with ALL the rows and evaluate on the same rows
  sel_all <- pick_features(x, y, k)
  apparent <- auc_rank(make_score(x, sel_all), y)
  # RIGHT: split first, choose on the training rows, evaluate on rows never used
  train_idx <- sample(n, round(0.7 * n))
  held_out <- setdiff(seq_len(n), train_idx)
  sel_train <- pick_features(x[train_idx, , drop = FALSE], y[train_idx], k)
  honest <- auc_rank(make_score(x[held_out, , drop = FALSE], sel_train), y[held_out])
  c(apparent = apparent, honest = honest)
}
set.seed(2026)
sim <- as.data.frame(t(replicate(100, simulate_double_dip())))
print(round(colMeans(sim), 3))
# Expected: the apparent AUC is far above 0.5 (around 0.85) and the honest one is near 0.5
stopifnot(mean(sim$apparent) > mean(sim$honest) + 0.2)
stopifnot(abs(mean(sim$honest) - 0.5) < 0.05)

sim_long <- pivot_longer(sim, cols = everything(), names_to = "evaluation", values_to = "auc")
p_dd <- ggplot(sim_long, aes(evaluation, auc)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = cesgen_blue[["grey"]]) +
  geom_boxplot(fill = cesgen_blue[["light"]]) +
  labs(title = "Pure noise: apparent versus honest performance",
       x = NULL, y = "AUC (100 simulated datasets)",
       caption = sim_caption("200 people, 500 noise features, 20 selected.")) +
  theme_cesgen()
ggsave("output/L32_double_dipping.png", p_dd, width = 6, height = 4, dpi = 150)

# ---- 5. Three partitions: train, validation, evaluation --------------------------------------
split_three <- function(n, props = c(train = 0.6, valid = 0.2, eval = 0.2)) {
  labels <- rep(names(props), times = round(props * n))
  labels <- c(labels, rep(names(props)[1], max(0, n - length(labels))))[seq_len(n)]
  sample(labels)
}
set.seed(7)
n <- 300
p <- 500
x <- matrix(rnorm(n * p), nrow = n, ncol = p)
y <- rbinom(n, 1, 0.5)
part <- split_three(n)
print(table(part))
r_train <- as.numeric(cor(x[part == "train", ], y[part == "train"]))
ranking <- order(abs(r_train), decreasing = TRUE)         # features ranked on training rows only
auc_for_k <- function(k, rows) {
  idx <- ranking[seq_len(k)]
  auc_rank(as.numeric(x[rows, idx, drop = FALSE] %*% sign(r_train[idx])), y[rows])
}
candidate_k <- c(5, 10, 20, 50)
valid_auc <- sapply(candidate_k, auc_for_k, rows = part == "valid")   # used to choose k
best_k <- candidate_k[which.max(valid_auc)]
final <- data.frame(
  part = c("train", "valid", "eval"),
  auc = c(auc_for_k(best_k, part == "train"),
          auc_for_k(best_k, part == "valid"),
          auc_for_k(best_k, part == "eval"))        # the evaluation part is looked at once
)
final$auc <- round(final$auc, 3)
print(data.frame(k = candidate_k, valid_auc = round(valid_auc, 3)))
print(final)
# Expected: train AUC well above 0.5, validation slightly flattering after choosing k,
# evaluation close to 0.5 because there is nothing to find.
stopifnot(final$auc[final$part == "train"] > final$auc[final$part == "eval"])

# ---- 6. What to take away ------------------------------------------------------------------
# * Report performance by group with n, events and intervals; say what the audit cannot show.
# * A measurement that drifts in one group biases every downstream result for that group.
# * Anything chosen with the data (variables, thresholds, k) belongs inside the training part.
# * Look at the evaluation part once.

# EXERCISE
# 1. In simulate_double_dip(), change p from 500 to 50 and k from 20 to 5. Run 100 repetitions.
#    Describe how the gap between apparent and honest AUC changes. Expected: a smaller gap
#    (apparent around 0.65-0.7), with the honest AUC still near 0.5.
# 2. Repeat the audit with the 90th percentile as the threshold. Compare the sensitivity by
#    group and say what the intervals allow you to claim. Expected: very wide intervals for G3.
# 3. For the measurement-bias block, take 100 G3 rows as a calibration sample where the true
#    value is known, estimate the offset, subtract it and recompute the flagged shares.
#    Expected: the G3 flagged share moves back close to flagged_true.
# Solutions: lessons/solutions/L32_solution.R
