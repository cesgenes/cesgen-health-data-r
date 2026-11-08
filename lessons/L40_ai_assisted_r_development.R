# =============================================================================
# Lesson 40: Developing, running, debugging and validating R code with AI assistants
# Goal:     play the adversarial reviewer. You receive a small analysis function, the
#           kind of code an assistant produces in seconds. It runs without errors and
#           its output looks reasonable, but it hides four flaws:
#             1. it joins genotypes and phenotypes by row position, not by patient_id;
#             2. it drops incomplete rows silently;
#             3. it selects SNPs on ALL the rows before the train/test split (leakage);
#             4. it flags SNPs at p < 0.05 with no multiple-testing correction.
#           Your job (EXERCISE at the end) is to write checks that expose each flaw.
# Inputs:   data-sim/out/population_pheno.csv, population_genotypes.csv and
#           population_truth.csv (the truth file is only used to judge the results)
# Outputs:  printed tables; output/L40_noise_test_correlation.png
# Packages: ggplot2 (everything else is base R). testthat is optional and is used
#           only in the solution file.
# Data:     Simulated data for teaching purposes. Runs in well under a minute.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# Privacy reminder (lesson 7): if you ask an AI assistant for help with this exercise,
# give it this script and the simulated data only. Never real patient data.
# =============================================================================

library(ggplot2)

source("R/helpers_general.R")          # theme_cesgen(), sim_caption(), cesgen_blue, ensure_sim_data()
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# ---- 1. Load the simulated population --------------------------------------------------------
pheno <- read.csv("data-sim/out/population_pheno.csv", stringsAsFactors = FALSE)
geno <- read.csv("data-sim/out/population_genotypes.csv", stringsAsFactors = FALSE)
truth <- read.csv("data-sim/out/population_truth.csv", stringsAsFactors = FALSE)
stopifnot(nrow(pheno) == nrow(geno),
          identical(pheno$patient_id, geno$patient_id),
          all(c("patient_id", "group", "trait") %in% names(pheno)),
          sum(truth$causal) >= 1)
cat("People:", nrow(pheno), "| SNPs:", sum(grepl("^snp", names(geno))),
    "| truly causal SNPs (known only because the data are simulated):", sum(truth$causal), "\n")

# ---- 2. Small helper functions (these are fine) ----------------------------------------------
# Run an expression with a fixed random seed, then put the caller's random state back.
# This way a function can be reproducible without disturbing the code that calls it.
with_seed <- function(seed, expr) {
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = env, inherits = FALSE)
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = env)
    } else if (exists(".Random.seed", envir = env, inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
  }, add = TRUE)
  set.seed(seed)
  expr
}

# One simple regression per SNP: trait ~ allele count. Returns snp, beta, p_value.
scan_snps <- function(y, g_mat) {
  rows <- lapply(colnames(g_mat), function(s) {
    co <- summary(lm(y ~ g_mat[, s]))$coefficients
    if (nrow(co) < 2) {
      return(data.frame(snp = s, beta = NA_real_, p_value = NA_real_))
    }
    data.frame(snp = s, beta = co[2, "Estimate"], p_value = co[2, "Pr(>|t|)"])
  })
  do.call(rbind, rows)
}

# ---- 3. The function under review (written quickly, looks reasonable) -------------------------
# Contract: f(pheno, geno, n_keep = 5, seed = 1) returns a list with
#   $table      data frame: snp, beta, p_value, significant (logical)
#   $selected   names of the SNPs used by the prediction model
#   $test_ids   patient_id values of the rows held out for testing
#   $test_cor   correlation between prediction and trait on the held-out rows
#   $n_used     number of rows the analysis used
flawed_snp_analysis <- function(pheno, geno, n_keep = 5, seed = 1) {
  snp_cols <- grep("^snp", names(geno), value = TRUE)

  # Join the two tables (assumes both list the people in the same order)
  dat <- cbind(pheno[, c("patient_id", "group", "trait")], geno[, snp_cols])

  # Keep complete rows only
  dat <- na.omit(dat)

  # Scan every SNP, flag the "significant" ones and keep the best n_keep for a prediction model
  tab <- scan_snps(dat$trait, as.matrix(dat[, snp_cols]))
  tab$significant <- !is.na(tab$p_value) & tab$p_value < 0.05
  selected <- tab$snp[order(tab$p_value)][seq_len(n_keep)]

  # Hold out 30% of the people and test the prediction model on them
  n_test <- round(0.3 * nrow(dat))
  test_rows <- with_seed(seed, sample(nrow(dat), n_test))
  train <- dat[-test_rows, , drop = FALSE]
  test <- dat[test_rows, , drop = FALSE]
  fit <- lm(reformulate(selected, response = "trait"), data = train)
  pred <- predict(fit, newdata = test)

  list(table = tab,
       selected = selected,
       test_ids = test$patient_id,
       test_cor = cor(pred, test$trait),
       n_used = nrow(dat))
}

# ---- 4. Run it on the simulated population: everything looks fine -----------------------------
res_flawed <- flawed_snp_analysis(pheno, geno, n_keep = 5, seed = 1)
cat("Rows used:", res_flawed$n_used, "of", nrow(pheno), "\n")
cat("Selected SNPs:", paste(res_flawed$selected, collapse = ", "), "\n")
cat("Correlation between prediction and trait on held-out people:",
    round(res_flawed$test_cor, 3), "\n")

tab <- res_flawed$table
tab$causal <- truth$causal[match(tab$snp, truth$snp)]
top <- tab[order(tab$p_value), ][1:10, ]
top$beta <- round(top$beta, 3)
top$p_value <- signif(top$p_value, 3)
cat("\nTen smallest p-values (column 'causal' comes from the truth file):\n")
print(top, row.names = FALSE)
cat("SNPs flagged at p < 0.05:", sum(tab$significant),
    "| of them NOT causal in the truth file:", sum(tab$significant & !tab$causal), "\n")
stopifnot(nrow(tab) == 40, length(res_flawed$selected) == 5, res_flawed$n_used == nrow(pheno))
# A reviewer cannot rely on the truth file in real work. The next section shows how to find
# problems with tests that do not need it.

# ---- 5. A red flag you can see without the truth: performance on pure noise -------------------
# Shuffle the trait so that NO SNP is related to it, then run the whole pipeline again.
# An honest pipeline should predict nothing on held-out people: correlation close to 0.
# Each study uses 150 people so that the effect of the flaw is easy to see.
run_null_studies <- function(f, pheno, geno, n_reps = 100, n_rows = 150, seed = 40) {
  with_seed(seed, {
    studies <- lapply(seq_len(n_reps), function(i) {
      rows <- sample(nrow(pheno), n_rows)
      p_i <- pheno[rows, , drop = FALSE]
      g_i <- geno[rows, , drop = FALSE]
      p_i$trait <- sample(p_i$trait)                 # break any link with the SNPs
      res <- f(p_i, g_i, seed = i)
      data.frame(test_cor = res$test_cor,
                 any_significant = any(res$table$significant, na.rm = TRUE))
    })
    do.call(rbind, studies)
  })
}

noise_flawed <- run_null_studies(flawed_snp_analysis, pheno, geno,
                                 n_reps = 100, n_rows = 150, seed = 40)
stopifnot(nrow(noise_flawed) == 100)
cat("\nPure-noise studies (100 repetitions, 150 people each):\n")
cat("  mean held-out correlation:", round(mean(noise_flawed$test_cor), 3),
    "(an honest pipeline gives about 0)\n")
cat("  share of studies with at least one 'significant' SNP:",
    round(mean(noise_flawed$any_significant), 2),
    "(with a correct 5% correction we expect about 0.05)\n")

p_noise <- ggplot(noise_flawed, aes(x = "Pipeline under review", y = test_cor)) +
  geom_boxplot(fill = cesgen_blue[["light"]]) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = cesgen_blue[["grey"]]) +
  labs(title = "Prediction on held-out people when the trait is pure noise",
       subtitle = "100 simulated studies; the dashed line is what an honest pipeline gives",
       x = NULL, y = "Correlation between prediction and trait",
       caption = sim_caption("Trait shuffled: no SNP is related to it.")) +
  theme_cesgen()
ggsave("output/L40_noise_test_correlation.png", p_noise, width = 5.5, height = 4, dpi = 150)
stopifnot(file.exists("output/L40_noise_test_correlation.png"))

# ---- 6. Scoreboard for the checks you will write ----------------------------------------------
# Every check has the same shape: check_xxx(f, pheno, geno) returns list(ok, detail).
# ok = TRUE means "the requirement is met"; ok = FALSE means "the flaw is exposed".
check_names <- c("check_row_alignment", "check_reports_dropped_rows",
                 "check_no_leakage", "check_false_positive_rate")

run_scoreboard <- function(f, pheno, geno, check_names) {
  for (nm in check_names) {
    if (!exists(nm, mode = "function")) {
      cat(sprintf("%-28s not written yet\n", nm))
      next
    }
    check_fun <- get(nm, mode = "function")
    res <- tryCatch(check_fun(f, pheno, geno),
                    error = function(e) list(ok = FALSE,
                                             detail = paste("check stopped:", conditionMessage(e))))
    status <- if (isTRUE(res$ok)) "requirement met" else "FLAW EXPOSED"
    cat(sprintf("%-28s %-16s %s\n", nm, status, paste(res$detail, collapse = " ")))
  }
  invisible(NULL)
}

cat("\nScoreboard for flawed_snp_analysis():\n")
run_scoreboard(flawed_snp_analysis, pheno, geno, check_names)

cat("\nL40 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# You are assistant B, the independent reviewer. Do not edit flawed_snp_analysis().
# Write one check per flaw, each as a function check_xxx(f, pheno, geno) that returns
# list(ok = TRUE/FALSE, detail = "one sentence"). Use the names in check_names.
#
# 1. check_row_alignment: the same people, with the genotype rows listed in another order,
#    must give the same result. Skeleton:
#      check_row_alignment <- function(f, pheno, geno) {
#        shuffled <- geno[with_seed(5, sample(nrow(geno))), , drop = FALSE]
#        a <- f(pheno, geno, seed = 11)
#        b <- f(pheno, shuffled, seed = 11)
#        ok <- isTRUE(all.equal(a$table$beta, b$table$beta))
#        list(ok = ok, detail = "...")
#      }
#
# 2. check_reports_dropped_rows: set the trait to NA for 100 people of group "G3". A safe
#    version must raise a warning that mentions the dropped rows and return n_dropped = 100.
#    Hint: withCallingHandlers() lets you catch a warning without stopping the function.
#
# 3. check_no_leakage: the held-out people must not influence which SNPs are selected.
#    Hint (a "canary"): run f once and take base$test_ids. Pick a SNP that was not selected.
#    Replace the trait of the held-out people by 1000 times that SNP's allele count and run
#    f again. If the canary SNP now appears in $selected, the held-out rows were used.
#    Remember to look genotypes up by patient_id (match()).
#
# 4. check_false_positive_rate: use run_null_studies(f, pheno, geno, n_reps = 40,
#    n_rows = 400, seed = 101) and compute the share of studies with at least one
#    significant SNP. Requirement: at most 0.20.
#
# 5. Run run_scoreboard(flawed_snp_analysis, pheno, geno, check_names).
#    Expected: all four checks print FLAW EXPOSED.
#
# 6. (Optional) Write safer_snp_analysis() that passes your four checks, and compare it
#    with the worked solution. Then ask an AI assistant to review your function with
#    templates/ai_assisted_workflow/adversarial_review_prompt.md and evaluate each finding.
#
# Worked solution: lessons/solutions/L40_solution.R
# =============================================================================
