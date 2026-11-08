# =============================================================================
# Lesson 10 - From SNP to trait: genotypes, allele frequencies, one-SNP traits
# Goal:     turn genotypes into allele counts, estimate allele frequencies by group,
#           estimate the effect of a single SNP on a trait and see its limit.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (one SIMULATED person)
#           data-sim/out/population_pheno.csv, population_genotypes.csv,
#           population_truth.csv  (SIMULATED population with known effects)
# Outputs:  console tables; output/L10_top_snp_trait.png
# Packages: readr, dplyr, tidyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
source("R/simulate_genotypes.R")

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# A. One person: from a genotype to "copies of the alternative allele"
# -----------------------------------------------------------------------------
count_allele <- function(genotype, allele) {
  allele <- rep_len(allele, length(genotype))
  vapply(seq_along(genotype), function(i) {
    if (is.na(genotype[i])) return(NA_integer_)
    sum(strsplit(genotype[i], "")[[1]] == allele[i])
  }, integer(1))
}
stopifnot(identical(count_allele(c("AG", "AA", "GG", NA), "A"), c(1L, 2L, 0L, NA_integer_)))

my_file <- read_tsv(
  "data-sim/out/genotype_consumer_sim.txt",
  comment = "#",
  col_names = c("rsid", "chromosome", "position", "genotype"),
  col_types = cols(rsid = col_character(), chromosome = col_character(),
                   position = col_double(), genotype = col_character())
)

anchor_calls <- my_file %>%
  inner_join(anchor_variants(), by = "rsid", suffix = c("", "_ref")) %>%
  mutate(
    genotype = na_if(genotype, "--"),
    alt_copies = count_allele(genotype, alt),
    meaning = case_when(
      is.na(alt_copies) ~ "no call",
      alt_copies == 0 ~ "no copy of the alternative allele",
      alt_copies == 1 ~ "one copy (heterozygous)",
      TRUE ~ "two copies (homozygous for the alternative allele)"
    )
  ) %>%
  select(rsid, genotype, ref, alt, alt_copies, meaning)
print(anchor_calls)
stopifnot(nrow(anchor_calls) == 6)
# A genotype alone says nothing about a trait: for that we need many people (below).

# -----------------------------------------------------------------------------
# B. A simulated population: allele frequencies and Hardy-Weinberg proportions
# -----------------------------------------------------------------------------
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
truth <- read_csv("data-sim/out/population_truth.csv", show_col_types = FALSE)

dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)
stopifnot(nrow(dat) == nrow(pheno), length(snp_cols) == 40, identical(truth$snp, snp_cols))
print(count(dat, group))

# Allele frequency = mean number of copies / 2
allele_freq <- function(dosage) mean(dosage, na.rm = TRUE) / 2
freq_overall <- sapply(dat[snp_cols], allele_freq)
print(summary(freq_overall))

freq_by_group <- dat %>%
  group_by(group) %>%
  summarise(across(all_of(snp_cols), allele_freq), .groups = "drop") %>%
  pivot_longer(-group, names_to = "snp", values_to = "freq")

freq_wide <- freq_by_group %>%
  pivot_wider(names_from = group, values_from = freq) %>%
  mutate(diff_G3_G1 = G3 - G1)
cat("\nSNPs whose frequency differs most between G3 and G1:\n")
print(head(arrange(freq_wide, desc(abs(diff_G3_G1))), 5))

# Hardy-Weinberg check: observed genotype counts against p^2, 2pq, q^2
hwe_test <- function(dosage) {
  n <- length(dosage)
  p <- mean(dosage) / 2
  observed <- as.numeric(table(factor(dosage, levels = 0:2)))
  expected <- n * c((1 - p)^2, 2 * p * (1 - p), p^2)
  stat <- sum((observed - expected)^2 / expected)
  data.frame(freq_alt = p, chi_sq = stat, p_value = 1 - pchisq(stat, df = 1))
}

hwe_in_g1 <- do.call(rbind, lapply(snp_cols, function(s) {
  cbind(snp = s, hwe_test(dat[[s]][dat$group == "G1"]))
}))
hwe_pooled <- do.call(rbind, lapply(snp_cols, function(s) {
  cbind(snp = s, hwe_test(dat[[s]]))
}))
cat("\nShare of SNPs with p < 0.05 in the Hardy-Weinberg check:\n")
cat("  within G1 only:", mean(hwe_in_g1$p_value < 0.05), "\n")
cat("  all groups pooled:", mean(hwe_pooled$p_value < 0.05), "\n")
# Within one homogeneous group about 5 % of SNPs are expected to fall below 0.05 by chance.
# Pooling groups with different frequencies can create apparent departures (population structure).

# -----------------------------------------------------------------------------
# C. One SNP at a time: effect on a continuous trait, and its limit
# -----------------------------------------------------------------------------
fit_one_snp <- function(snp, data) {
  d <- data.frame(trait = data$trait, x = data[[snp]])
  fit <- lm(trait ~ x, data = d)
  co <- summary(fit)$coefficients
  data.frame(
    snp = snp,
    beta_hat = co["x", "Estimate"],
    std_error = co["x", "Std. Error"],
    p_value = co["x", "Pr(>|t|)"],
    r_squared = summary(fit)$r.squared
  )
}

single_snp <- do.call(rbind, lapply(snp_cols, fit_one_snp, data = dat)) %>%
  left_join(truth, by = "snp") %>%
  mutate(true_effect_trait = 4 * beta) %>%   # the generator multiplies the genetic score by 4
  arrange(p_value)

cat("\nTop single-SNP associations with the trait (estimated effect vs known truth):\n")
print(head(select(single_snp, snp, beta_hat, p_value, r_squared, causal, true_effect_trait), 8))
print(table(p_below_005 = single_snp$p_value < 0.05, truly_causal = single_snp$causal))

top_snp <- single_snp$snp[1]
cat("\nTop SNP:", top_snp, " effect per copy:", round(single_snp$beta_hat[1], 2),
    " share of trait variance explained (R squared):", round(single_snp$r_squared[1], 3), "\n")

# The limit, in one number: if you pick one person with two copies and one with none,
# how often does the person with the "higher-trait" genotype really have the higher value?
higher_prob <- function(x_high, x_low) mean(outer(x_high, x_low, ">"))
high_dosage <- if (single_snp$beta_hat[1] > 0) 2 else 0
low_dosage <- 2 - high_dosage
x_high <- dat$trait[dat[[top_snp]] == high_dosage]
x_low <- dat$trait[dat[[top_snp]] == low_dosage]
stopifnot(length(x_high) > 10, length(x_low) > 10)
prob_higher <- higher_prob(x_high, x_low)
cat("Probability that a person with the 'high' genotype has a higher trait value than one with",
    "the 'low' genotype:", round(prob_higher, 2), "\n")

plot_df <- data.frame(
  copies = factor(dat[[top_snp]], levels = 0:2, labels = c("0 copies", "1 copy", "2 copies")),
  trait = dat$trait
)
p_top <- ggplot(plot_df, aes(x = copies, y = trait)) +
  geom_jitter(width = 0.2, alpha = 0.25, colour = cesgen_blue[["light"]]) +
  geom_boxplot(width = 0.5, outlier.shape = NA, fill = NA, colour = cesgen_blue[["dark"]]) +
  labs(
    title = paste("Trait by genotype at", top_snp, "(simulated)"),
    x = "Copies of the alternative allele", y = "Trait value",
    caption = sim_caption("The groups differ on average, but they overlap.")
  ) +
  theme_cesgen()
ggsave("output/L10_top_snp_trait.png", p_top, width = 6, height = 4.5, dpi = 150)

stopifnot(prob_higher > 0.5, prob_higher < 1)

# =============================================================================
# EXERCISE (Try this) - about 15 minutes
# Take the SNP ranked second in the 'single_snp' table and report:
#   (a) its allele frequency in G1 and in G3,
#   (b) its estimated effect per copy and its R squared,
#   (c) the probability that a person with the 'high' genotype has a higher trait
#       value than a person with the 'low' genotype,
#   (d) one sentence on what a person with two copies can and cannot conclude.
# Expected: frequencies that differ by a few percentage points, an R squared that is a
# small share of the variance, and a probability above 0.5 but clearly below 1.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L10_solution.R
# =============================================================================
