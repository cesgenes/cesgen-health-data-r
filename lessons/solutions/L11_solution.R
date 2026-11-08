# =============================================================================
# Lesson 11 - Worked solution
# Task:     effect of the training fraction on the test R squared, over several seeds.
# Inputs:   data-sim/out/population_*.csv  (SIMULATED)
# Outputs:  console only
# Packages: readr, dplyr
# Run from the repository root. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
library(readr)
library(dplyr)
ensure_sim_data()

pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)
x_all <- as.matrix(dat[snp_cols])
y_trait <- dat$trait
n <- nrow(dat)

r2_out <- function(observed, predicted) {
  1 - sum((observed - predicted)^2) / sum((observed - mean(observed))^2)
}

test_r2_all_snps <- function(train_fraction, seed) {
  set.seed(seed)
  train_idx <- sample(n, size = round(train_fraction * n))
  test_idx <- setdiff(seq_len(n), train_idx)
  fit <- lm(y ~ ., data = data.frame(y = y_trait[train_idx], x_all[train_idx, ]))
  pred <- predict(fit, newdata = data.frame(x_all[test_idx, ]))
  r2_out(y_trait[test_idx], pred)
}

grid <- expand.grid(train_fraction = c(0.7, 0.3), seed = 1:5)
grid$r2_test <- mapply(test_r2_all_snps, grid$train_fraction, grid$seed)
print(grid)

summary_table <- grid %>%
  group_by(train_fraction) %>%
  summarise(mean_r2 = mean(r2_test), min_r2 = min(r2_test), max_r2 = max(r2_test), .groups = "drop")
print(summary_table)

stopifnot(nrow(summary_table) == 2, all(summary_table$max_r2 < 1))
# Reading: a smaller training set gives a noisier model, so the test R squared is usually
# lower and its range across seeds is wider. A single split is one draw from that range.
