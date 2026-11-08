# =============================================================================
# Solution for lesson 40 (run from the repository root).
# 1. Four reviewer checks that expose the four flaws of flawed_snp_analysis().
# 2. A safer version, safer_snp_analysis(), that passes all four checks.
# 3. Known-truth and pure-noise validation of the safer version.
# Data: Simulated data for teaching purposes. Educational material; it does not
# replace a health professional.
# =============================================================================

# Load the data, the helpers, the flawed function and run_null_studies() from the lesson script.
# (This also prints the lesson output and the scoreboard with "not written yet" lines.)
source("lessons/L40_ai_assisted_r_development.R")

# ---- 1. The four reviewer checks ----------------------------------------------------------------

# Flaw 1: join by position. Same people, genotype rows in another order, must give the same result.
check_row_alignment <- function(f, pheno, geno) {
  shuffled <- geno[with_seed(5, sample(nrow(geno))), , drop = FALSE]
  a <- f(pheno, geno, seed = 11)
  b <- tryCatch(f(pheno, shuffled, seed = 11), error = function(e) NULL)
  ok <- !is.null(b) && isTRUE(all.equal(a$table$beta, b$table$beta))
  detail <- if (ok) "same result when the genotype rows are reordered" else "result changes when the same genotypes are listed in another order"
  list(ok = ok, detail = detail)
}

# Flaw 2: silent removal of incomplete rows. A safe version warns and reports how many were dropped.
check_reports_dropped_rows <- function(f, pheno, geno) {
  g3_rows <- which(pheno$group == "G3")
  stopifnot(length(g3_rows) >= 100)
  pheno_na <- pheno
  pheno_na$trait[g3_rows[1:100]] <- NA
  warned <- FALSE
  res <- tryCatch(
    withCallingHandlers(
      f(pheno_na, geno, seed = 11),
      warning = function(w) {
        if (grepl("dropp", conditionMessage(w), ignore.case = TRUE)) warned <<- TRUE
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) NULL
  )
  counted <- !is.null(res) && identical(as.integer(res$n_dropped), 100L)
  detail <- paste0("warning about dropped rows: ", warned, "; n_dropped = 100 reported: ", counted)
  list(ok = warned && counted, detail = detail)
}

# Flaw 3: leakage. A "canary" SNP is made to look hugely associated with the trait, but only in
# the held-out people. If the selection ignores those people, the canary cannot be selected.
check_no_leakage <- function(f, pheno, geno) {
  base <- f(pheno, geno, seed = 11)
  snp_cols <- grep("^snp", names(geno), value = TRUE)
  canary <- setdiff(snp_cols, base$selected)[1]
  in_test <- pheno$patient_id %in% base$test_ids
  geno_pos <- match(pheno$patient_id, geno$patient_id)
  poisoned <- pheno
  poisoned$trait[in_test] <- 1000 * geno[[canary]][geno_pos][in_test]
  after <- f(poisoned, geno, seed = 11)
  ok <- !(canary %in% after$selected)
  detail <- if (ok) "held-out people did not influence the selection" else paste("canary", canary, "was selected: held-out rows were used to choose SNPs")
  list(ok = ok, detail = detail)
}

# Flaw 4: no multiple-testing correction. With 40 SNPs and no real effect, about 87% of
# studies would flag something at p < 0.05; a correct 5% correction keeps this near 5%.
check_false_positive_rate <- function(f, pheno, geno) {
  runs <- run_null_studies(f, pheno, geno, n_reps = 40, n_rows = 400, seed = 101)
  rate <- mean(runs$any_significant)
  detail <- sprintf("share of pure-noise studies with a 'significant' SNP: %.2f (requirement: at most 0.20)", rate)
  list(ok = rate <= 0.20, detail = detail)
}

# ---- 2. The safer version -----------------------------------------------------------------------
safer_snp_analysis <- function(pheno, geno, n_keep = 5, seed = 1, alpha = 0.05) {
  snp_cols <- grep("^snp", names(geno), value = TRUE)
  stopifnot(all(c("patient_id", "group", "trait") %in% names(pheno)),
            length(snp_cols) > 0,
            !anyDuplicated(pheno$patient_id),
            !anyDuplicated(geno$patient_id))

  # Fix 1: join by patient_id, never by position; stop if somebody is missing
  pos <- match(pheno$patient_id, geno$patient_id)
  if (anyNA(pos)) {
    stop("Some patient_id values in 'pheno' are missing from 'geno'.")
  }
  dat <- cbind(pheno[, c("patient_id", "group", "trait")], geno[pos, snp_cols, drop = FALSE])
  rownames(dat) <- NULL

  # Fix 2: remove incomplete rows, but say how many and where
  complete <- stats::complete.cases(dat)
  n_dropped <- sum(!complete)
  if (n_dropped > 0) {
    by_group <- table(dat$group[!complete])
    warning(sprintf("Dropped %d of %d rows with missing values (by group: %s).",
                    n_dropped, nrow(dat),
                    paste(names(by_group), as.integer(by_group), sep = "=", collapse = ", ")),
            call. = FALSE)
  }
  dat <- dat[complete, , drop = FALSE]

  # Fix 3: split FIRST; scan and select using the training people only
  n_test <- round(0.3 * nrow(dat))
  test_rows <- with_seed(seed, sample(nrow(dat), n_test))
  train <- dat[-test_rows, , drop = FALSE]
  test <- dat[test_rows, , drop = FALSE]
  tab <- scan_snps(train$trait, as.matrix(train[, snp_cols]))

  # Fix 4: Bonferroni correction over all the SNPs tested
  tab$p_adjusted <- p.adjust(tab$p_value, method = "bonferroni")
  tab$significant <- !is.na(tab$p_adjusted) & tab$p_adjusted < alpha
  selected <- tab$snp[order(tab$p_value)][seq_len(n_keep)]

  fit <- lm(reformulate(selected, response = "trait"), data = train)
  pred <- predict(fit, newdata = test)

  list(table = tab,
       selected = selected,
       test_ids = test$patient_id,
       test_cor = cor(pred, test$trait),
       n_used = nrow(dat),
       n_dropped = n_dropped)
}

# ---- 3. The checks expose the flawed function and pass the safer one ----------------------------
cat("\n--- Scoreboard: flawed_snp_analysis() ---\n")
run_scoreboard(flawed_snp_analysis, pheno, geno, check_names)
cat("\n--- Scoreboard: safer_snp_analysis() ---\n")
run_scoreboard(safer_snp_analysis, pheno, geno, check_names)

run_checks <- function(f) {
  lapply(setNames(check_names, check_names), function(nm) {
    tryCatch(get(nm, mode = "function")(f, pheno, geno),
             error = function(e) list(ok = FALSE, detail = conditionMessage(e)))
  })
}
flawed_ok <- vapply(run_checks(flawed_snp_analysis), function(r) isTRUE(r$ok), logical(1))
safer_ok <- vapply(run_checks(safer_snp_analysis), function(r) isTRUE(r$ok), logical(1))
stopifnot(!any(flawed_ok))     # every flaw is exposed
stopifnot(all(safer_ok))       # the safer version meets every requirement

# ---- 4. The same checks as a testthat test (what you would keep in tests/testthat) --------------
if (requireNamespace("testthat", quietly = TRUE)) {
  testthat::test_that("safer_snp_analysis() meets the four reviewer checks", {
    for (nm in check_names) {
      res <- get(nm, mode = "function")(safer_snp_analysis, pheno, geno)
      testthat::expect_true(res$ok, info = paste(nm, "-", res$detail))
    }
  })
} else {
  message("Package testthat is not installed: skipping the testthat version of the checks.")
}

# ---- 5. Validation that does not rely on the checks alone ---------------------------------------
# (a) Known truth: the corrected analysis should recover planted effects.
res_safe <- safer_snp_analysis(pheno, geno, n_keep = 5, seed = 1)
flagged <- res_safe$table$snp[res_safe$table$significant]
causal_snps <- truth$snp[truth$causal]
cat("\nSNPs flagged after Bonferroni correction (training people only):", length(flagged), "\n")
cat("  of them truly causal in the truth file:", length(intersect(flagged, causal_snps)),
    "| not causal:", length(setdiff(flagged, causal_snps)), "\n")
cat("  causal SNPs missed (small effects are hard to detect):",
    length(setdiff(causal_snps, flagged)), "\n")
stopifnot(length(intersect(flagged, causal_snps)) >= 1)
stopifnot(res_safe$n_dropped == 0, res_safe$n_used == nrow(pheno))

# (b) Pure noise: the held-out correlation should centre on 0 for the safer version.
noise_safe <- run_null_studies(safer_snp_analysis, pheno, geno,
                               n_reps = 100, n_rows = 150, seed = 40)
cat("\nMean held-out correlation on pure noise (100 studies of 150 people):\n")
cat("  pipeline under review:", round(mean(noise_flawed$test_cor), 3),
    "| safer version:", round(mean(noise_safe$test_cor), 3), "\n")
cat("Share of noise studies with a 'significant' SNP: ",
    round(mean(noise_flawed$any_significant), 2), "versus", round(mean(noise_safe$any_significant), 2), "\n")
stopifnot(abs(mean(noise_safe$test_cor)) < 0.06)
stopifnot(mean(noise_flawed$test_cor) > mean(noise_safe$test_cor) + 0.03)

# (c) Same data, same seed, same answer: reproducibility.
res_again <- safer_snp_analysis(pheno, geno, n_keep = 5, seed = 1)
stopifnot(identical(res_safe$selected, res_again$selected),
          isTRUE(all.equal(res_safe$test_cor, res_again$test_cor)))

# ---- 6. What the checks do NOT prove ------------------------------------------------------------
# Passing four checks shows that these four flaws are gone. It does not show that the model is
# right, that Bonferroni is the best choice here, or that a simulated result applies to real
# patients. A second reviewer should now attack safer_snp_analysis() again; log each finding,
# decide (accept, reject with a reason, defer), fix, and re-run the checks. The human decides.

cat("\nL40 solution finished: the four flaws are exposed and the safer version passes all checks.\n")
