# Solution for lesson 21 (run from the repository root).
# It runs the lesson script first (to reuse its objects and functions), then answers the three tasks.
library(dplyr)
library(readr)

source("R/helpers_general.R")
ensure_sim_data()
source("lessons/L21_phewas_run.R")

# 1. Which planted phenotypes pass Bonferroni in site A alone, and pooled?
found_site_a <- truth_check %>% select(phenotype_id, phenotype, true_or, or, found_bonferroni)
found_pooled <- pooled %>%
  filter(phenotype_id %in% truth$phenotype_id) %>%
  transmute(phenotype_id, pooled_or = round(pooled_or, 2), found_bonferroni_pooled = p_bonferroni < 0.05)
print(left_join(found_site_a, found_pooled, by = "phenotype_id"))

# 2. A stricter minimum number of exposed patients (30 instead of 10)
res_a_30 <- run_phewas(wide_a, phenotype_ids, min_exposed = 30) %>% add_corrections(phenotype_map)
n_tests_30 <- sum(!is.na(res_a_30$p_value))
cat("\nTests run with min_exposed = 30:", n_tests_30, "(was", n_valid_a, ")\n")
cat("New Bonferroni threshold:", signif(0.05 / n_tests_30, 3),
    "(was", signif(bonferroni_threshold_a, 3), ")\n")
cat("Bonferroni hits:", sum(res_a_30$p_bonferroni < 0.05, na.rm = TRUE), "\n")

# 3. Stacked analysis with site as a covariate, versus the pooled estimate, for PH01
stacked <- bind_rows(wide_a %>% mutate(site = "A"), wide_b %>% mutate(site = "B"))
fit_stacked <- glm(ade ~ PH01 + age + sex + site, data = stacked, family = binomial())
stacked_or <- tidy_or(fit_stacked, "PH01")
pooled_ph01 <- pooled %>% filter(phenotype_id == "PH01") %>% select(pooled_or, lower, upper)
cat("\nPH01 odds ratio, stacked with site covariate:\n"); print(round(stacked_or[, c("or", "lower", "upper")], 2))
cat("PH01 odds ratio, two-site meta-analysis:\n"); print(round(pooled_ph01, 2))

stopifnot(n_tests_30 <= n_valid_a, nrow(stacked) == 2000, is.finite(stacked_or$or))
