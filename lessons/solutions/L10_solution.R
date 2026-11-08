# =============================================================================
# Lesson 10 - Worked solution
# Task:     report frequency by group, effect, R squared and overlap for the
#           second-ranked SNP.
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

fit_one_snp <- function(snp, data) {
  d <- data.frame(trait = data$trait, x = data[[snp]])
  fit <- lm(trait ~ x, data = d)
  co <- summary(fit)$coefficients
  data.frame(snp = snp, beta_hat = co["x", "Estimate"], p_value = co["x", "Pr(>|t|)"],
             r_squared = summary(fit)$r.squared)
}
ranking <- do.call(rbind, lapply(snp_cols, fit_one_snp, data = dat)) %>% arrange(p_value)
second <- ranking[2, ]
snp <- second$snp
cat("Second-ranked SNP:", snp, "\n")

# (a) allele frequency in G1 and G3
freq_g1 <- mean(dat[[snp]][dat$group == "G1"]) / 2
freq_g3 <- mean(dat[[snp]][dat$group == "G3"]) / 2
cat("Frequency in G1:", round(freq_g1, 3), " in G3:", round(freq_g3, 3), "\n")

# (b) effect per copy and R squared
cat("Effect per copy:", round(second$beta_hat, 2), " R squared:", round(second$r_squared, 3), "\n")

# (c) probability that the 'high' genotype has the higher trait value
high_dosage <- if (second$beta_hat > 0) 2 else 0
x_high <- dat$trait[dat[[snp]] == high_dosage]
x_low <- dat$trait[dat[[snp]] == 2 - high_dosage]
stopifnot(length(x_high) > 10, length(x_low) > 10)
prob_higher <- mean(outer(x_high, x_low, ">"))
cat("Probability high genotype > low genotype:", round(prob_higher, 2), "\n")
stopifnot(prob_higher > 0.5, prob_higher < 1)

# (d) One sentence (write your own): with two copies, the average trait value is shifted by
# about twice the effect per copy, but individual values overlap widely with those of people
# who carry no copy, so the genotype describes a group average and does not predict this person.
