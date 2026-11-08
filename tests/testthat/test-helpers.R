test_that("or_to_absolute_risk: an odds ratio of 1 gives the baseline, 2 gives 2/11", {
  expect_equal(or_to_absolute_risk(1, 0.1), 0.1)
  expect_equal(or_to_absolute_risk(2, 0.1), 2 / 11, tolerance = 1e-12)   # odds 1/9 * 2 = 2/9
  expect_equal(or_to_absolute_risk(c(1, 2), 0.5), c(0.5, 2 / 3), tolerance = 1e-12)
  expect_error(or_to_absolute_risk(2, 1.2))
  expect_error(or_to_absolute_risk(-1, 0.1))
})

test_that("bonferroni_threshold divides alpha by the number of tests", {
  expect_equal(bonferroni_threshold(1000), 5e-5)
  expect_equal(bonferroni_threshold(40, alpha = 0.01), 0.00025)
})

test_that("k_anonymity reports the smallest group, the number of groups and singletons", {
  df <- data.frame(a = c("x", "x", "y", "z", "z", "z"), b = c(1, 1, 2, 3, 3, 3))
  res <- k_anonymity(df, c("a", "b"))
  expect_equal(res$k, 1)
  expect_equal(res$n_groups, 3)
  expect_equal(res$n_unique, 1)
  expect_error(k_anonymity(df, "missing_column"))
})

test_that("flag_identifier_columns flags identifier-like names and nothing else", {
  df <- data.frame(patient_name = 1, postcode = 1, age = 1, glucose = 1)
  expect_equal(sort(flag_identifier_columns(df)$column), c("patient_name", "postcode"))
  expect_equal(nrow(flag_identifier_columns(data.frame(age = 1, glucose = 1))), 0)
})

test_that("tidy_or reproduces the hand-computed odds ratio and Wald interval of a 2x2 table", {
  # cells: exposed 30 events / 70 none, unexposed 10 events / 90 none
  d <- data.frame(y = c(rep(1, 30), rep(0, 70), rep(1, 10), rep(0, 90)),
                  x = c(rep(1, 100), rep(0, 100)))
  fit <- glm(y ~ x, data = d, family = binomial)
  res <- tidy_or(fit, "x")
  or <- (30 * 90) / (70 * 10)
  se <- sqrt(1 / 30 + 1 / 70 + 1 / 10 + 1 / 90)
  expect_equal(res$or, or, tolerance = 1e-6)
  expect_equal(res$lower, exp(log(or) - 1.96 * se), tolerance = 1e-3)   # glm converges to ~1e-4
  expect_equal(res$upper, exp(log(or) + 1.96 * se), tolerance = 1e-3)
  expect_true(is.na(tidy_or(fit, "not_a_term")$or))
})

test_that("sim_caption always carries the simulated-data statement", {
  expect_match(sim_caption(), "Simulated data for teaching purposes")
  expect_match(sim_caption("Extra note."), "Extra note\\.$")
})

test_that("simulated generators are reproducible and respect their structure", {
  e1 <- simulate_ehr(500, "A", 2026)
  e2 <- simulate_ehr(500, "A", 2026)
  expect_identical(e1$patients, e2$patients)
  expect_identical(e1$diagnoses, e2$diagnoses)
  expect_equal(nrow(e1$phenotypes), 40)
  expect_false(identical(e1$patients$ade, simulate_ehr(500, "B", 2026)$patients$ade))
  p <- simulate_population(500, 20, 2026)
  expect_true(all(p$geno %in% 0:2))
  expect_equal(nrow(p$pheno), 500)
  expect_equal(sum(p$truth$causal), 8)
})

test_that("consumer file has header comments, forward-strand note and '--' no-calls", {
  f <- tempfile(fileext = ".txt")
  simulate_consumer_file(f, n_snps = 200, seed = 1, nocall_rate = 0.1)
  lines <- readLines(f)
  expect_true(any(startsWith(lines, "#")))
  expect_true(any(grepl("\t--$", lines)))
  body <- lines[!startsWith(lines, "#")]
  expect_equal(length(body), 200)
  expect_true(all(c("rs1801133", "rs1805007") %in% sub("\t.*", "", body)))
})

test_that("anchor variants carry the dbSNP GRCh37 coordinates checked on 2026-11-08", {
  a <- anchor_variants()
  expect_equal(a$position[a$rsid == "rs1805007"], 89986117L)
  expect_equal(a$position[a$rsid == "rs4988235"], 136608646L)
  expect_equal(a$chromosome[a$rsid == "rs429358"], "19")
  expect_equal(nrow(a), 6)
})
