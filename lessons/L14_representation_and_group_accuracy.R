# =============================================================================
# Lesson 14 - Who is missing from the data: representation and accuracy by group
# Goal:     (A) draw a representation chart and compare study participants with a
#           reference population; (B) measure how the accuracy of a score differs
#           between groups G1-G3 in a simulated population.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv  (SIMULATED)
# Outputs:  output/L14_representation_simulated.png, output/L14_accuracy_by_group.png,
#           output/L14_frequency_shift.png, console tables
# Packages: readr, dplyr, tidyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes / Datos simulados con fin didactico.
# =============================================================================

source("R/helpers_general.R")

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# =============================================================================
# PART A. Representation chart
# =============================================================================

# A function that draws study share against reference-population share, by group
plot_representation <- function(df, title, caption) {
  long <- df %>%
    select(group, share_in_studies, share_in_population) %>%
    pivot_longer(c(share_in_studies, share_in_population), names_to = "measure", values_to = "share") %>%
    mutate(measure = factor(measure,
                            levels = c("share_in_studies", "share_in_population"),
                            labels = c("Participants in studies", "Reference population")))
  ggplot(long, aes(x = group, y = share, fill = measure)) +
    geom_col(position = "dodge") +
    scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    scale_fill_manual(values = c(cesgen_blue[["mid"]], cesgen_blue[["accent"]])) +
    labs(title = title, x = NULL, y = "Share of the total", fill = NULL, caption = caption) +
    theme_cesgen()
}

check_shares <- function(df) {
  c(studies = sum(df$share_in_studies), population = sum(df$share_in_population))
}

# -----------------------------------------------------------------------------
# A1. ILLUSTRATIVE, INVENTED NUMBERS - NOT REAL FIGURES
#     "Group A-E" are generic labels; the proportions only show how to read the chart.
#     Datos simulados con fin didactico: no representan ninguna poblacion real.
# -----------------------------------------------------------------------------
sim_representation <- data.frame(
  group = paste("Group", c("A", "B", "C", "D", "E")),
  share_in_studies = c(0.62, 0.15, 0.10, 0.08, 0.05),        # INVENTED
  share_in_population = c(0.30, 0.25, 0.20, 0.15, 0.10),     # INVENTED
  stringsAsFactors = FALSE
)
stopifnot(all(abs(check_shares(sim_representation) - 1) < 1e-9))

sim_representation <- sim_representation %>%
  mutate(representation_ratio = share_in_studies / share_in_population)
print(sim_representation, digits = 3)
# Ratio below 1: the group is under-represented in studies relative to the reference population.

p_sim <- plot_representation(
  sim_representation,
  title = "ILLUSTRATIVE ONLY: invented proportions",
  caption = sim_caption("Datos simulados con fin didactico. Not real figures.")
)
ggsave("output/L14_representation_simulated.png", p_sim, width = 7, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# A2. TEMPLATE for REAL, source-checked figures
#     Fill in group names, shares and the provenance table from a source you have
#     opened and checked yourself. Check access and licence before using any data.
# -----------------------------------------------------------------------------
real_figures <- data.frame(
  group = c("<group 1>", "<group 2>", "<group 3>", "<group 4>", "<group 5>"),
  share_in_studies = NA_real_,       # e.g. 0.xx, copied from the source
  share_in_population = NA_real_,    # e.g. 0.xx, copied from the source
  stringsAsFactors = FALSE
)
real_provenance <- data.frame(
  item = c("source_for_studies", "source_for_population", "release_or_version", "date_accessed",
           "how_groups_were_defined", "licence_and_access_checked"),
  value = NA_character_,
  stringsAsFactors = FALSE
)

if (anyNA(real_figures$share_in_studies) || anyNA(real_figures$share_in_population)) {
  message("Template not filled in yet: paste your source-checked figures above to draw the real chart.")
} else {
  sums <- check_shares(real_figures)
  if (any(abs(sums - 1) > 0.02)) warning("Shares do not add up to 1: check the categories (is an 'other' group missing?).")
  p_real <- plot_representation(
    real_figures,
    title = "Representation (source-checked figures)",
    caption = "Source, version and date: see the provenance table."
  )
  ggsave("output/L14_representation_real.png", p_real, width = 7, height = 4.5, dpi = 150)
}
print(real_provenance)

# =============================================================================
# PART B. Accuracy of a score by group (simulated population, known truth)
# =============================================================================
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)
cat("\nPeople per group:\n")
print(count(dat, group))

# Helpers ---------------------------------------------------------------------
auc <- function(score, outcome) {
  n1 <- sum(outcome == 1)
  n0 <- sum(outcome == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  ranks <- rank(score)
  (sum(ranks[outcome == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
cor_sq <- function(x, y) cor(x, y)^2

# Bootstrap interval (resample people with replacement)
boot_ci <- function(stat_fn, x, y, B = 200) {
  est <- stat_fn(x, y)
  boots <- replicate(B, {
    i <- sample(length(x), replace = TRUE)
    stat_fn(x[i], y[i])
  })
  c(estimate = est,
    lower = unname(quantile(boots, 0.025, na.rm = TRUE)),
    upper = unname(quantile(boots, 0.975, na.rm = TRUE)))
}

# One weight per SNP, from one regression per SNP (linear for the trait, logistic for the disease)
estimate_weights <- function(data, snp_cols, outcome = c("trait", "disease")) {
  outcome <- match.arg(outcome)
  vapply(snp_cols, function(s) {
    d <- data.frame(y = data[[outcome]], x = data[[s]])
    fit <- if (outcome == "trait") lm(y ~ x, data = d) else glm(y ~ x, data = d, family = binomial)
    unname(coef(fit)[2])
  }, numeric(1))
}
compute_score <- function(data, snp_cols, weights) {
  as.vector(as.matrix(data[snp_cols]) %*% weights[snp_cols])
}

# Split ------------------------------------------------------------------------
set.seed(14)
train_idx <- sample(nrow(dat), size = round(0.7 * nrow(dat)))
train <- dat[train_idx, ]
test <- dat[-train_idx, ]
stopifnot(nrow(train) + nrow(test) == nrow(dat))
cat("\nPeople per group in the test set:\n")
print(count(test, group))

# Accuracy by group for one way of building the weights -------------------------
evaluate_scenario <- function(train, test, scenario) {
  w_trait <- estimate_weights(train, snp_cols, "trait")
  w_disease <- estimate_weights(train, snp_cols, "disease")
  test$score_trait <- compute_score(test, snp_cols, w_trait)
  test$score_disease <- compute_score(test, snp_cols, w_disease)
  rows <- lapply(c("G1", "G2", "G3"), function(g) {
    d <- test[test$group == g, ]
    r2 <- boot_ci(cor_sq, d$score_trait, d$trait)
    a <- boot_ci(auc, d$score_disease, d$disease)
    data.frame(
      scenario = scenario, group = g, n_test = nrow(d), n_cases = sum(d$disease),
      r2_trait = r2[["estimate"]], r2_lower = r2[["lower"]], r2_upper = r2[["upper"]],
      auc = a[["estimate"]], auc_lower = a[["lower"]], auc_upper = a[["upper"]]
    )
  })
  do.call(rbind, rows)
}

results <- rbind(
  evaluate_scenario(train, test, "weights from all groups"),
  evaluate_scenario(train[train$group == "G1", ], test, "weights from G1 only")
)
cat("\nAccuracy by group, with bootstrap 95 % intervals (simulated data):\n")
print(results, digits = 3)
stopifnot(nrow(results) == 6, all(results$n_test > 0))

p_acc <- ggplot(results, aes(x = group, y = r2_trait, colour = scenario)) +
  geom_pointrange(aes(ymin = r2_lower, ymax = r2_upper), position = position_dodge(width = 0.4)) +
  scale_colour_manual(values = c(cesgen_blue[["mid"]], cesgen_blue[["accent"]])) +
  labs(
    title = "Accuracy of a trait score by group (simulated)",
    x = "Group", y = "R squared in the test set (95 % bootstrap interval)", colour = NULL,
    caption = sim_caption("Datos simulados con fin didactico. Effects are identical in all groups here.")
  ) +
  theme_cesgen()
ggsave("output/L14_accuracy_by_group.png", p_acc, width = 7, height = 4.5, dpi = 150)

# The score distribution also differs by group ----------------------------------
w_pooled <- estimate_weights(train, snp_cols, "trait")
test$score <- compute_score(test, snp_cols, w_pooled)

score_by_group <- test %>%
  group_by(group) %>%
  summarise(n = n(), mean_score = mean(score), sd_score = sd(score), .groups = "drop")
print(score_by_group, digits = 3)

# A cut-off defined in G1 (top 10 % of G1) classifies other groups differently
cutoff_g1 <- unname(quantile(test$score[test$group == "G1"], 0.9))
share_above <- test %>%
  group_by(group) %>%
  summarise(share_above_g1_top_decile = mean(score > cutoff_g1), .groups = "drop")
cat("\nShare of each group above the cut-off defined as the top 10 % of G1:\n")
print(share_above, digits = 3)

# Why: allele frequencies differ between groups -------------------------------------
freq_by_group <- dat %>%
  group_by(group) %>%
  summarise(across(all_of(snp_cols), ~ mean(.x) / 2), .groups = "drop") %>%
  pivot_longer(-group, names_to = "snp", values_to = "freq") %>%
  pivot_wider(names_from = group, values_from = freq) %>%
  pivot_longer(c(G2, G3), names_to = "other_group", values_to = "freq_other")

p_freq <- ggplot(freq_by_group, aes(x = G1, y = freq_other)) +
  geom_abline(slope = 1, intercept = 0, colour = cesgen_blue[["grey"]]) +
  geom_point(colour = cesgen_blue[["mid"]], alpha = 0.7) +
  facet_wrap(~ other_group) +
  labs(
    title = "Allele frequency in G2 and G3 against G1 (simulated)",
    x = "Frequency in G1", y = "Frequency in the other group",
    caption = sim_caption("Points off the diagonal: frequencies that differ between groups.")
  ) +
  theme_cesgen()
ggsave("output/L14_frequency_shift.png", p_freq, width = 8, height = 4, dpi = 150)

# Reading the results (do not skip) -----------------------------------------------
# * In this simulation the genetic effects are the SAME in every group, so any gap comes from
#   different allele frequencies and from the number of people per group.
# * Small groups give wide intervals: a group whose interval is wide and overlaps the others
#   has NOT been shown to be equal; the data are also compatible with a large gap.
# * In real data additional reasons (different linkage patterns between variants, different effects
#   or environments) can widen the gap. Always report accuracy by group, with intervals and sizes.

# =============================================================================
# EXERCISE (Try this) - about 20 minutes
# 1. Fill the template in part A2 with figures from a public source that you have opened and
#    checked (two or more groups are enough to test the code): fill the provenance table too, and
#    re-run. Expected: the real chart is saved and no message about an empty template appears.
#    If you have no checked source yet, test the code with invented numbers and delete them afterwards.
# 2. From the 'results' table, report which group has the lowest R squared and the widest interval
#    in each scenario, and write one sentence on what you can and cannot conclude.
#    Expected: usually the smallest group (G3) has the widest interval in both scenarios.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L14_solution.R
# =============================================================================
