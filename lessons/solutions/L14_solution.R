# =============================================================================
# Lesson 14 - Worked solution
# Task:     (1) show how the representation template is filled and checked;
#           (2) find the group with the lowest R squared and the widest interval.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv  (SIMULATED)
# Outputs:  output/L14_solution_representation_demo.png, console tables
# Packages: readr, dplyr, tidyr, ggplot2
# Run from the repository root. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# Task 1 -------------------------------------------------------------------
# The numbers below are INVENTED to test the code. In real work, replace them with figures you
# have opened and checked at the source, and fill the provenance table.
demo_figures <- data.frame(
  group = c("Group X", "Group Y", "Group Z"),
  share_in_studies = c(0.80, 0.15, 0.05),        # INVENTED
  share_in_population = c(0.40, 0.35, 0.25),     # INVENTED
  stringsAsFactors = FALSE
)
stopifnot(!anyNA(demo_figures), abs(sum(demo_figures$share_in_studies) - 1) < 1e-9,
          abs(sum(demo_figures$share_in_population) - 1) < 1e-9)

demo_figures <- demo_figures %>% mutate(representation_ratio = share_in_studies / share_in_population)
print(demo_figures, digits = 3)

p_demo <- demo_figures %>%
  pivot_longer(c(share_in_studies, share_in_population), names_to = "measure", values_to = "share") %>%
  ggplot(aes(x = group, y = share, fill = measure)) +
  geom_col(position = "dodge") +
  labs(title = "TEST WITH INVENTED NUMBERS", x = NULL, y = "Share",
       caption = sim_caption("Datos simulados con fin didactico. Not real figures.")) +
  theme_cesgen()
ggsave("output/L14_solution_representation_demo.png", p_demo, width = 6, height = 4, dpi = 150)

# Provenance: what to write down for real figures (placeholders shown here)
provenance <- data.frame(
  item = c("source_for_studies", "source_for_population", "release_or_version", "date_accessed",
           "how_groups_were_defined", "licence_and_access_checked"),
  value = c("<publication or database page>", "<publication or database page>", "<release>",
            "<date you opened it>", "<definition used by the source>", "<yes/no, with the terms read>"),
  stringsAsFactors = FALSE
)
print(provenance)

# Task 2 -------------------------------------------------------------------
pheno <- read_csv("data-sim/out/population_pheno.csv", show_col_types = FALSE)
geno <- read_csv("data-sim/out/population_genotypes.csv", show_col_types = FALSE)
dat <- inner_join(pheno, geno, by = "patient_id")
snp_cols <- grep("^snp", names(dat), value = TRUE)

cor_sq <- function(x, y) cor(x, y)^2
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
estimate_trait_weights <- function(data, snp_cols) {
  vapply(snp_cols, function(s) {
    d <- data.frame(y = data$trait, x = data[[s]])
    unname(coef(lm(y ~ x, data = d))[2])
  }, numeric(1))
}
compute_score <- function(data, snp_cols, weights) {
  as.vector(as.matrix(data[snp_cols]) %*% weights[snp_cols])
}

set.seed(14)
train_idx <- sample(nrow(dat), size = round(0.7 * nrow(dat)))
train <- dat[train_idx, ]
test <- dat[-train_idx, ]

run_scenario <- function(train_data, scenario) {
  w <- estimate_trait_weights(train_data, snp_cols)
  test$score <- compute_score(test, snp_cols, w)
  do.call(rbind, lapply(c("G1", "G2", "G3"), function(g) {
    d <- test[test$group == g, ]
    r2 <- boot_ci(cor_sq, d$score, d$trait)
    data.frame(scenario = scenario, group = g, n_test = nrow(d), r2 = r2[["estimate"]],
               lower = r2[["lower"]], upper = r2[["upper"]], width = r2[["upper"]] - r2[["lower"]])
  }))
}

results <- rbind(
  run_scenario(train, "weights from all groups"),
  run_scenario(train[train$group == "G1", ], "weights from G1 only")
)
print(results, digits = 3)

summary_by_scenario <- results %>%
  group_by(scenario) %>%
  summarise(lowest_r2_group = group[which.min(r2)], widest_interval_group = group[which.max(width)],
            .groups = "drop")
print(summary_by_scenario)
stopifnot(nrow(results) == 6, nrow(summary_by_scenario) == 2)

# One sentence (write your own after reading the table). Example of the reasoning:
# "The point estimates differ by group, but the intervals of the smaller groups are wide and overlap
# those of G1, so the data neither show equal accuracy nor prove a gap in this simulation; with
# identical effects in all groups, the differences come from allele frequencies and sample size."
