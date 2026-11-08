# =============================================================================
# Lesson 21: Run a PheWAS in R and correct for multiple comparisons
# Goal:     (1) reshape long diagnoses into a patient x phenotype matrix,
#           (2) fit one logistic regression per phenotype (outcome: adverse drug
#               event, ADE), (3) collect odds ratios with tidy_or(),
#           (4) correct p-values (Bonferroni and Benjamini-Hochberg),
#           (5) draw a Manhattan-style plot and a forest plot,
#           (6) compare the findings with the planted truth,
#           (7) replicate in the second site and pool both with meta::metagen.
# Inputs:   data-sim/out/ehr_A_*.csv, ehr_B_*.csv, phenotype_map.csv, ehr_truth.csv
# Outputs:  output/L21_phewas_site_A.csv, output/L21_manhattan_site_A.png,
#           output/L21_forest_site_A.png, output/L21_pooled_forest.png
# Packages: readr, dplyr, tidyr, purrr, ggplot2, meta
# Data:     Simulated data for teaching purposes. The truth table (ehr_truth.csv)
#           exists ONLY because the data are simulated; real PheWAS have no such table.
# IMPORTANT: a PheWAS result is a hypothesis to follow up, not a clinical conclusion.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(meta)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Read data
# -----------------------------------------------------------------------------
read_site <- function(site) {
  list(
    patients  = read_csv(sprintf("data-sim/out/ehr_%s_patients.csv", site), show_col_types = FALSE),
    diagnoses = read_csv(sprintf("data-sim/out/ehr_%s_diagnoses.csv", site), show_col_types = FALSE)
  )
}
site_a <- read_site("A")
site_b <- read_site("B")
phenotype_map <- read_csv("data-sim/out/phenotype_map.csv", show_col_types = FALSE)
truth <- read_csv("data-sim/out/ehr_truth.csv", show_col_types = FALSE)
phenotype_ids <- phenotype_map$phenotype_id

# Small helper: keep three significant digits in every numeric column when printing
round_for_print <- function(df) df %>% mutate(across(where(is.numeric), ~ signif(.x, 3)))

# -----------------------------------------------------------------------------
# 2. Long diagnoses -> one row per patient, one 0/1 column per phenotype
# -----------------------------------------------------------------------------
make_pheno_matrix <- function(patients, diagnoses, phenotype_ids) {
  presence <- diagnoses %>%
    distinct(patient_id, phenotype_id) %>%
    mutate(present = 1L)
  wide <- presence %>%
    pivot_wider(names_from = phenotype_id, values_from = present, values_fill = 0L)
  out <- patients %>%
    select(patient_id, sex, age, ade) %>%
    left_join(wide, by = "patient_id")
  for (ph in phenotype_ids) {                         # patients without a record, or phenotypes never seen
    if (!ph %in% names(out)) out[[ph]] <- 0L
    out[[ph]][is.na(out[[ph]])] <- 0L
  }
  out
}

wide_a <- make_pheno_matrix(site_a$patients, site_a$diagnoses, phenotype_ids)
wide_b <- make_pheno_matrix(site_b$patients, site_b$diagnoses, phenotype_ids)

# Cross-check the reshape with base R table(): the total number of 1s must agree
check_total <- sum(table(factor(site_a$diagnoses$patient_id, levels = site_a$patients$patient_id),
                         factor(site_a$diagnoses$phenotype_id, levels = phenotype_ids)) > 0)
stopifnot(nrow(wide_a) == nrow(site_a$patients),
          sum(as.matrix(wide_a[, phenotype_ids])) == check_total)
cat("Matrix site A:", nrow(wide_a), "patients x", length(phenotype_ids), "phenotypes\n")

# -----------------------------------------------------------------------------
# 3. One logistic regression per phenotype: ade ~ phenotype + age + sex
# -----------------------------------------------------------------------------
run_phewas <- function(wide, phenotype_ids, min_exposed = 10) {
  map_dfr(phenotype_ids, function(ph) {
    d <- data.frame(ade = wide$ade, x = wide[[ph]], age = wide$age, sex = wide$sex)
    n_exposed <- sum(d$x == 1)
    events_exposed <- sum(d$x == 1 & d$ade == 1)
    if (n_exposed < min_exposed) {                    # too few cases: do not fit, report NA
      out <- data.frame(term = "x", or = NA_real_, lower = NA_real_, upper = NA_real_,
                        p_value = NA_real_)
    } else {
      fit <- suppressWarnings(glm(ade ~ x + age + sex, data = d, family = binomial()))
      out <- tidy_or(fit, "x")
    }
    out$phenotype_id <- ph
    out$n_exposed <- n_exposed
    out$events_exposed <- events_exposed
    out
  })
}

# -----------------------------------------------------------------------------
# 4. Multiple-testing correction, applied once, over the tests that were run
# -----------------------------------------------------------------------------
add_corrections <- function(res, phenotype_map) {
  res <- res %>%
    left_join(phenotype_map %>% select(phenotype_id, phenotype), by = "phenotype_id")
  valid <- !is.na(res$p_value)
  res$p_bonferroni <- NA_real_
  res$p_bh <- NA_real_
  res$p_bonferroni[valid] <- p.adjust(res$p_value[valid], method = "bonferroni")
  res$p_bh[valid] <- p.adjust(res$p_value[valid], method = "BH")
  res$log_or <- log(res$or)
  res$se_log_or <- (log(res$upper) - log(res$lower)) / (2 * 1.96)   # tidy_or() uses 1.96
  res
}

res_a <- run_phewas(wide_a, phenotype_ids) %>% add_corrections(phenotype_map)
res_b <- run_phewas(wide_b, phenotype_ids) %>% add_corrections(phenotype_map)
write_csv(res_a, "output/L21_phewas_site_A.csv")

n_valid_a <- sum(!is.na(res_a$p_value))
bonferroni_threshold_a <- bonferroni_threshold(n_valid_a)
cat("\nTests run in site A:", n_valid_a, "- Bonferroni threshold:", signif(bonferroni_threshold_a, 3), "\n")
cat("Nominal p < 0.05:        ", sum(res_a$p_value < 0.05, na.rm = TRUE), "\n")
cat("Benjamini-Hochberg < 0.05:", sum(res_a$p_bh < 0.05, na.rm = TRUE), "\n")
cat("Bonferroni < 0.05:       ", sum(res_a$p_bonferroni < 0.05, na.rm = TRUE), "\n")

cat("\nTen smallest p-values in site A:\n")
print(res_a %>% arrange(p_value) %>%
        select(phenotype_id, phenotype, n_exposed, events_exposed, or, lower, upper, p_value, p_bonferroni, p_bh) %>%
        head(10) %>% round_for_print())

# -----------------------------------------------------------------------------
# 5. Manhattan-style plot: -log10(p) per phenotype
# -----------------------------------------------------------------------------
manhattan_plot <- function(res, truth_ids, title) {
  threshold <- 0.05 / sum(!is.na(res$p_value))
  plot_df <- res %>%
    filter(!is.na(p_value)) %>%
    arrange(phenotype_id) %>%
    mutate(position = row_number(),
           neg_log10_p = -log10(p_value),
           planted = phenotype_id %in% truth_ids,
           passes = p_value < threshold)
  ggplot(plot_df, aes(x = position, y = neg_log10_p)) +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed", colour = cesgen_blue[["grey"]]) +
    geom_hline(yintercept = -log10(threshold), colour = cesgen_blue[["accent"]]) +
    geom_point(aes(colour = passes, shape = planted), size = 2.6) +
    geom_text(data = filter(plot_df, passes), aes(label = phenotype),
              hjust = -0.15, size = 3, colour = cesgen_blue[["dark"]]) +
    scale_colour_manual(values = c(`FALSE` = cesgen_blue[["grey"]], `TRUE` = cesgen_blue[["mid"]])) +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17)) +
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.2))) +
    labs(title = title,
         subtitle = "Dashed line: p = 0.05 (uncorrected). Solid line: Bonferroni threshold.",
         x = "Phenotype (order in the dictionary)", y = expression(-log[10](p)),
         colour = "Passes Bonferroni", shape = "Planted in the simulation",
         caption = sim_caption()) +
    theme_cesgen()
}
p_manhattan <- manhattan_plot(res_a, truth$phenotype_id, "PheWAS of adverse drug events, site A")
ggsave("output/L21_manhattan_site_A.png", p_manhattan, width = 8, height = 5, dpi = 150)

# -----------------------------------------------------------------------------
# 6. Forest plot: odds ratios with 95% CI for the planted phenotypes and every
#    phenotype that passed Bonferroni (crosses mark the planted odds ratio)
# -----------------------------------------------------------------------------
forest_plot <- function(res, truth, title) {
  keep_ids <- union(truth$phenotype_id, res$phenotype_id[which(res$p_bonferroni < 0.05)])
  d <- res %>%
    filter(phenotype_id %in% keep_ids, !is.na(or)) %>%
    left_join(truth, by = "phenotype_id") %>%
    mutate(label = reorder(paste(phenotype_id, phenotype), or))
  ggplot(d, aes(x = or, y = label, xmin = lower, xmax = upper)) +
    geom_vline(xintercept = 1, linetype = "dashed", colour = cesgen_blue[["grey"]]) +
    geom_pointrange(colour = cesgen_blue[["mid"]]) +
    geom_point(aes(x = true_or), shape = 4, size = 3, stroke = 1.2,
               colour = cesgen_blue[["accent"]], na.rm = TRUE) +
    scale_x_log10() +
    labs(title = title, x = "Odds ratio (log scale), 95% CI", y = NULL,
         caption = sim_caption("Crosses: planted odds ratio, known only because the data are simulated.")) +
    theme_cesgen()
}
p_forest <- forest_plot(res_a, truth, "Selected PheWAS results, site A")
ggsave("output/L21_forest_site_A.png", p_forest, width = 8, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# 7. Compare with the planted truth (possible only with simulated data)
# -----------------------------------------------------------------------------
truth_check <- truth %>%
  left_join(res_a %>% select(phenotype_id, phenotype, or, lower, upper, p_value, p_bonferroni, p_bh),
            by = "phenotype_id") %>%
  mutate(ci_contains_truth = lower <= true_or & true_or <= upper,
         found_bonferroni = coalesce(p_bonferroni < 0.05, FALSE),
         found_bh = coalesce(p_bh < 0.05, FALSE))
cat("\nPlanted associations versus estimates (site A):\n")
print(round_for_print(truth_check))

null_summary <- res_a %>%
  filter(!phenotype_id %in% truth$phenotype_id, !is.na(p_value)) %>%
  summarise(null_phenotypes = n(),
            nominal = sum(p_value < 0.05),
            bh = sum(p_bh < 0.05),
            bonferroni = sum(p_bonferroni < 0.05))
cat("\nPhenotypes with NO planted effect that look 'significant':\n")
print(null_summary)
# Small effects (such as OR 1.5) can be missed in 1,000 patients: that is limited power.

# -----------------------------------------------------------------------------
# 8. Replication and a two-site meta-analysis
# -----------------------------------------------------------------------------
cat("\nSite B, same analysis: Bonferroni hits =", sum(res_b$p_bonferroni < 0.05, na.rm = TRUE), "\n")

combined <- res_a %>%
  select(phenotype_id, phenotype, n_a = n_exposed, events_a = events_exposed,
         log_or_a = log_or, se_a = se_log_or) %>%
  inner_join(res_b %>% select(phenotype_id, n_b = n_exposed, events_b = events_exposed,
                              log_or_b = log_or, se_b = se_log_or),
             by = "phenotype_id")

# Zero (or near-zero) events in an exposed group make the odds ratio explode:
# keep only phenotypes with finite, reasonably small standard errors and events in both sites
combined <- combined %>%
  mutate(usable = is.finite(log_or_a) & is.finite(log_or_b) &
           is.finite(se_a) & is.finite(se_b) &
           se_a < 5 & se_b < 5 & events_a > 0 & events_b > 0)
cat("Phenotypes usable in the meta-analysis:", sum(combined$usable), "of", nrow(combined), "\n")
cat("\nNot usable (few cases or zero events in an exposed group):\n")
print(combined %>% filter(!usable) %>% select(phenotype_id, phenotype, n_a, events_a, n_b, events_b))

pool_two_sites <- function(te, se, labels = c("A", "B")) {
  m <- meta::metagen(TE = te, seTE = se, studlab = labels, sm = "OR")
  # field names changed between versions of the meta package: try the new name first
  get_field <- function(new_name, old_name) {
    if (!is.null(m[[new_name]])) m[[new_name]] else m[[old_name]]
  }
  data.frame(pooled_log_or = get_field("TE.common", "TE.fixed"),
             pooled_se = get_field("seTE.common", "seTE.fixed"),
             pooled_p = get_field("pval.common", "pval.fixed"),
             i2 = m$I2)
}

usable_rows <- combined %>% filter(usable)
pooled_list <- lapply(seq_len(nrow(usable_rows)), function(i) {
  pool_two_sites(te = c(usable_rows$log_or_a[i], usable_rows$log_or_b[i]),
                 se = c(usable_rows$se_a[i], usable_rows$se_b[i]))
})
pooled <- bind_cols(usable_rows %>% select(phenotype_id, phenotype), bind_rows(pooled_list)) %>%
  mutate(pooled_or = exp(pooled_log_or),
         lower = exp(pooled_log_or - 1.96 * pooled_se),
         upper = exp(pooled_log_or + 1.96 * pooled_se),
         p_bonferroni = p.adjust(pooled_p, method = "bonferroni"),
         p_bh = p.adjust(pooled_p, method = "BH"))

# Check metagen against the inverse-variance formula written by hand
w_a <- 1 / usable_rows$se_a^2
w_b <- 1 / usable_rows$se_b^2
manual_log_or <- (w_a * usable_rows$log_or_a + w_b * usable_rows$log_or_b) / (w_a + w_b)
stopifnot(all(abs(manual_log_or - pooled$pooled_log_or) < 1e-6))

cat("\nPooled (two sites, common-effect model) - smallest p-values:\n")
print(pooled %>% arrange(pooled_p) %>%
        select(phenotype_id, phenotype, pooled_or, lower, upper, pooled_p, p_bonferroni, i2) %>%
        head(8) %>% round_for_print())
cat("Pooled hits after Bonferroni:", sum(pooled$p_bonferroni < 0.05), "\n")

# Forest plot for the planted phenotypes: site A, site B and pooled
forest_long <- bind_rows(
  res_a %>% filter(phenotype_id %in% truth$phenotype_id) %>%
    transmute(phenotype_id, phenotype, source = "Site A", or, lower, upper),
  res_b %>% filter(phenotype_id %in% truth$phenotype_id) %>%
    transmute(phenotype_id, phenotype, source = "Site B", or, lower, upper),
  pooled %>% filter(phenotype_id %in% truth$phenotype_id) %>%
    transmute(phenotype_id, phenotype, source = "Pooled", or = pooled_or, lower, upper)
) %>%
  mutate(label = paste(phenotype_id, phenotype),
         source = factor(source, levels = c("Site A", "Site B", "Pooled")))

p_pooled <- ggplot(forest_long, aes(x = or, y = label, xmin = lower, xmax = upper, colour = source)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = cesgen_blue[["grey"]]) +
  geom_pointrange(position = position_dodge(width = 0.6)) +
  scale_x_log10() +
  scale_colour_manual(values = c(`Site A` = cesgen_blue[["mid"]], `Site B` = cesgen_blue[["accent"]],
                                 Pooled = cesgen_blue[["dark"]])) +
  labs(title = "Planted associations: two sites and pooled estimate",
       x = "Odds ratio (log scale), 95% CI", y = NULL, colour = NULL, caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L21_pooled_forest.png", p_pooled, width = 8, height = 4.5, dpi = 150)

# -----------------------------------------------------------------------------
# 9. What a zero cell does, and one simple remedy (continuity correction)
# -----------------------------------------------------------------------------
or_2x2 <- function(exp_event, exp_none, unexp_event, unexp_none, correction = 0.5) {
  cells <- c(exp_event, exp_none, unexp_event, unexp_none)
  if (any(cells == 0)) cells <- cells + correction     # add 0.5 to every cell if any cell is zero
  log_or <- log((cells[1] * cells[4]) / (cells[2] * cells[3]))
  se <- sqrt(sum(1 / cells))
  data.frame(or = exp(log_or), lower = exp(log_or - 1.96 * se), upper = exp(log_or + 1.96 * se))
}
cat("\nToy table with a zero cell (0 events among 6 exposed; 60 among 994 unexposed):\n")
print(round_for_print(or_2x2(exp_event = 0, exp_none = 6, unexp_event = 60, unexp_none = 934)))
cat("The corrected interval is wide: a rare phenotype with zero events tells us very little.\n")

# -----------------------------------------------------------------------------
# 10. Sanity checks
# -----------------------------------------------------------------------------
stopifnot(nrow(res_a) == length(phenotype_ids),
          all(res_a$p_value[!is.na(res_a$p_value)] >= 0 & res_a$p_value[!is.na(res_a$p_value)] <= 1),
          all(res_a$p_bonferroni[!is.na(res_a$p_bonferroni)] >= res_a$p_value[!is.na(res_a$p_value)]),
          nrow(pooled) == sum(combined$usable),
          file.exists("output/L21_manhattan_site_A.png"),
          file.exists("output/L21_forest_site_A.png"),
          file.exists("output/L21_pooled_forest.png"))
cat("\nL21 finished: all sanity checks passed.\n")
cat("Reminder: every association above is a hypothesis that needs follow-up, not a clinical conclusion.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Run the script and read the table of planted associations (section 7).
#    Which planted phenotypes pass Bonferroni in site A alone? And pooled?
# 2. Change min_exposed from 10 to 30 in run_phewas() and rerun sections 3-4.
#    How many tests remain, and how does the Bonferroni threshold change?
# 3. Repeat the analysis in the stacked data (site A + site B) with `site` as an
#    extra covariate, and compare the odds ratio for PH01 with the pooled one.
# Expected: PH01 (the strongest planted effect) stands out in the Manhattan plot
# and its estimate is close to 3.5; weaker planted effects (PH03, PH05) may be
# missed in one site and gain support when pooled; most phenotypes have no effect
# and a few look nominally significant by chance.
# Worked solution: lessons/solutions/L21_solution.R
# =============================================================================
