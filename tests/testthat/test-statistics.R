test_that("planted PH01, PH03 and PH05 are recovered after Bonferroni in a large site", {
  e <- simulate_ehr(20000, "A", 2026)
  m <- pheno_matrix(e)
  res <- do.call(rbind, lapply(colnames(m), function(ph) {
    d <- data.frame(ade = e$patients$ade, x = m[, ph], age = e$patients$age, sex = e$patients$sex)
    out <- tidy_or(suppressWarnings(glm(ade ~ x + age + sex, data = d, family = binomial())), "x")
    out$phenotype_id <- ph
    out
  }))
  hits <- res$phenotype_id[res$p_value < bonferroni_threshold(nrow(res))]
  expect_true(all(c("PH01", "PH03", "PH05") %in% hits))
  expect_lte(length(setdiff(hits, c("PH01", "PH03", "PH05"))), 1)    # familywise error about 5 %
  planted <- merge(e$truth, res, by = "phenotype_id")
  expect_true(all(planted$lower <= planted$true_or & planted$true_or <= planted$upper))
})

test_that("under the null, p-values are calibrated and the false-positive rate is near 5 %", {
  set.seed(20)
  p <- replicate(150, {
    outcome <- rbinom(1000, 1, 0.07)
    vapply(runif(40, 0.05, 0.30), function(prev) {
      exposure <- rbinom(1000, 1, prev)
      summary(suppressWarnings(glm(outcome ~ exposure, family = binomial())))$coefficients[2, 4]
    }, numeric(1))
  })
  expect_gt(mean(p < 0.05), 0.035)
  expect_lt(mean(p < 0.05), 0.065)
  expect_gt(mean(p < 0.50), 0.45)
  expect_lt(mean(p < 0.50), 0.55)
  # With Bonferroni the chance of any false positive in a study is about 5 %. With 150 studies the
  # number of studies with a false positive is Binomial(150, 0.05); allow up to its 99.99th percentile.
  any_fp <- apply(p, 2, function(x) any(p.adjust(x, "bonferroni") < 0.05))
  expect_lte(sum(any_fp), qbinom(0.9999, 150, 0.05))
  expect_gte(sum(any_fp), qbinom(0.0001, 150, 0.05))
})

test_that("95 % Wald intervals from tidy_or cover the true odds ratio about 95 % of the time", {
  set.seed(21)
  covered <- replicate(400, {
    x <- rbinom(2000, 1, 0.3)
    y <- rbinom(2000, 1, plogis(qlogis(0.1) + log(2) * x))
    r <- tidy_or(glm(y ~ x, family = binomial()), "x")
    r$lower <= 2 && 2 <= r$upper
  })
  expect_gt(mean(covered), 0.92)
  expect_lt(mean(covered), 0.98)
})

test_that("two-site meta-analysis matches inverse-variance weights, incl. a zero-event table", {
  skip_if_not_installed("meta")
  f <- lesson_functions("lessons/L21_phewas_run.R", c("pool_two_sites", "or_2x2"))
  te <- c(log(2.0), log(1.5)); se <- c(0.2, 0.3)
  res <- f$pool_two_sites(te, se)
  w <- 1 / se^2
  expect_equal(res$pooled_log_or, sum(w * te) / sum(w), tolerance = 1e-8)
  expect_equal(res$pooled_se, sqrt(1 / sum(w)), tolerance = 1e-8)
  # no zero cell: no correction, OR is the cross-product ratio
  expect_equal(f$or_2x2(10, 90, 20, 180)$or, 1, tolerance = 1e-12)
  # zero cell: 0.5 is added to every cell, giving a finite OR and a wide interval
  z <- f$or_2x2(0, 6, 60, 934)
  expect_equal(z$or, (0.5 * 934.5) / (6.5 * 60.5), tolerance = 1e-12)
  expect_true(is.finite(z$upper) && z$lower > 0)
  expect_gt(log(z$upper) - log(z$lower), 2)
})

test_that("double-dipping: apparent AUC on noise is high, honest AUC is about 0.5", {
  f <- lesson_functions("lessons/L32_bias_audit_and_double_dipping.R",
                        c("auc_rank", "pick_features", "make_score", "simulate_double_dip"))
  expect_equal(f$auc_rank(c(0.1, 0.4, 0.35, 0.8), c(0, 0, 1, 1)), 0.75)
  set.seed(2026)
  sim <- as.data.frame(t(replicate(60, f$simulate_double_dip())))
  expect_gt(mean(sim$apparent), mean(sim$honest) + 0.2)
  expect_lt(abs(mean(sim$honest) - 0.5), 0.06)
})

test_that("a score trained on G1 only is less accurate in G3 than in G1 (large simulated sample)", {
  f <- lesson_functions("lessons/L14_representation_and_group_accuracy.R",
                        c("estimate_weights", "compute_score", "cor_sq"))
  p <- simulate_population(30000, 40, 2026)
  d <- cbind(p$pheno, as.data.frame(p$geno))
  snp <- colnames(p$geno)
  w <- f$estimate_weights(d[d$group == "G1", ], snp, "trait")
  score <- f$compute_score(d, snp, w)
  r2 <- tapply(seq_len(nrow(d)), d$group, function(i) f$cor_sq(score[i], d$trait[i]))
  expect_lt(r2[["G3"]], r2[["G1"]])
  expect_equal(unname(table(d$group)[["G3"]]) < unname(table(d$group)[["G1"]]), TRUE)
})

test_that("Moran's I of exposure and deprivation is positive on the simulated areas", {
  skip_if_not_installed("sf")
  skip_if_not_installed("spdep")
  a <- simulate_areas(seed = 2026)
  lw <- spdep::nb2listw(spdep::poly2nb(a, queen = TRUE), style = "W")
  expect_gt(spdep::moran.test(a$pm25, lw)$estimate[["Moran I statistic"]], 0.3)
  expect_gt(spdep::moran.test(a$deprivation, lw)$estimate[["Moran I statistic"]], 0.3)
  set.seed(1)
  shuffled <- sample(a$pm25)
  expect_lt(abs(spdep::moran.test(shuffled, lw)$estimate[["Moran I statistic"]]), 0.15)
})

test_that("privacy helpers: suppression hides 1 to 4 and meets_k follows k_anonymity", {
  f <- lesson_functions("lessons/L28_privacy_small_numbers.R", c("meets_k", "suppress_small_counts"))
  d <- data.frame(g = c("a", "b", "c", "d"), n = c(0, 3, 5, 120))
  s <- f$suppress_small_counts(d, "n", 5)
  expect_equal(s$count_shown, c("0", "<5", "5", "120"))
  expect_equal(s$suppressed, c(FALSE, TRUE, FALSE, FALSE))
  expect_error(f$suppress_small_counts(d, "n", 1))
  df <- data.frame(a = c("x", "x", "x", "x", "x", "y"))
  expect_true(f$meets_k(df[1:5, , drop = FALSE], "a", 5))
  expect_false(f$meets_k(df, "a", 5))
})

test_that("re-identification demo: the register and the release share the quasi-identifiers", {
  sim <- simulate_reid_demo(500, 2026)
  expect_equal(nrow(sim$register), 500)
  expect_equal(nrow(sim$release), 500)
  key <- function(x) sort(do.call(paste, x[c("sex", "birth_year", "district")]))
  expect_identical(key(sim$register), key(sim$release))
  expect_false("person_id" %in% names(sim$release))
})

test_that("a quasi-Poisson model with offset recovers the planted rate ratios on the simulated areas", {
  skip_if_not_installed("sf")
  est <- t(vapply(1:60, function(sd) {
    a <- sf::st_drop_geometry(simulate_areas(seed = sd))
    coef(glm(cases ~ pm25 + deprivation + offset(log(population / 1000)),
             data = a, family = quasipoisson))[c("pm25", "deprivation")]
  }, numeric(2)))
  # planted: log rate ratio 0.04 per unit of pm25 and 0.25 per unit of the deprivation index
  # Monte Carlo standard error of each mean is below 0.004, so 0.015 is about four standard errors
  expect_lt(abs(mean(est[, "pm25"]) - 0.04), 0.015)
  expect_lt(abs(mean(est[, "deprivation"]) - 0.25), 0.015)
})

test_that("L21 corrections: p_bonferroni and p_bh are the adjusted p-values over the tests run", {
  f <- lesson_functions("lessons/L21_phewas_run.R", c("run_phewas", "add_corrections"))
  suppressMessages(library(purrr)); suppressMessages(library(dplyr))
  env <- list2env(list(map_dfr = purrr::map_dfr, tidy_or = tidy_or), parent = globalenv())
  environment(f$run_phewas) <- env
  environment(f$add_corrections) <- env
  e <- simulate_ehr(3000, "A", 2026)
  wide <- cbind(e$patients[c("sex", "age", "ade")], as.data.frame(pheno_matrix(e)))
  res <- f$add_corrections(f$run_phewas(wide, e$phenotypes$phenotype_id), e$phenotypes)
  ok <- !is.na(res$p_value)
  k <- sum(ok)
  expect_gt(k, 20)
  expect_equal(res$p_bonferroni[ok], pmin(1, res$p_value[ok] * k))        # Bonferroni by hand
  expect_equal(res$p_bh[ok], p.adjust(res$p_value[ok], method = "BH"))
  expect_true(all(res$p_bonferroni[ok] >= res$p_bh[ok] - 1e-12))
  expect_true(any(res$p_bonferroni[ok] > res$p_value[ok]))                 # corrected, not raw
  expect_true(all(is.na(res$p_bonferroni[!ok])) && all(is.na(res$p_bh[!ok])))
  # hand-made table: the 3 tests run are corrected with 3, the untested row stays NA
  tab <- data.frame(phenotype_id = c("PH01", "PH02", "PH03", "PH04"), or = c(2, 1.1, 1.5, NA),
                    lower = c(1.2, 0.8, 1.1, NA), upper = c(3.3, 1.5, 2.0, NA),
                    p_value = c(0.001, 0.4, 0.03, NA))
  out <- f$add_corrections(tab, e$phenotypes)
  expect_equal(out$p_bonferroni, c(0.003, 1, 0.09, NA))
  expect_equal(out$p_bh, c(0.003, 0.4, 0.045, NA))
})
