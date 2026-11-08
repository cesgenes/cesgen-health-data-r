# Run from the repository root: testthat::test_dir("tests/testthat")
invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source))

test_that("odds ratio of 1 gives the baseline risk", {
  expect_equal(or_to_absolute_risk(1, 0.1), 0.1)
})

test_that("odds ratio converts to the right absolute risk", {
  # baseline odds 1/9; times 2 = 2/9; risk = 2/11
  expect_equal(or_to_absolute_risk(2, 0.1), 2 / 11, tolerance = 1e-12)
})

test_that("bonferroni threshold divides alpha by the number of tests", {
  expect_equal(bonferroni_threshold(1000), 5e-5)
})

test_that("k_anonymity reports the smallest group", {
  df <- data.frame(a = c("x", "x", "y"), b = c(1, 1, 2))
  res <- k_anonymity(df, c("a", "b"))
  expect_equal(res$k, 1)
  expect_equal(res$n_unique, 1)
})

test_that("simulated EHR is reproducible and has the planted structure", {
  e1 <- simulate_ehr(500, "A", 2026); e2 <- simulate_ehr(500, "A", 2026)
  expect_identical(e1$patients, e2$patients)
  expect_true(all(c("patient_id", "ade") %in% names(e1$patients)))
  expect_equal(nrow(e1$phenotypes), 40)
})

test_that("planted association is recoverable", {
  e <- simulate_ehr(4000, "A", 2026)
  d <- e$diagnoses
  x <- as.integer(e$patients$patient_id %in% d$patient_id[d$phenotype_id == "PH01"])
  m <- glm(e$patients$ade ~ x, family = binomial)
  expect_gt(exp(coef(m)[["x"]]), 2)
})

test_that("population simulation returns genotypes coded 0/1/2", {
  p <- simulate_population(500, 20, 2026)
  expect_true(all(p$geno %in% 0:2))
  expect_equal(nrow(p$pheno), 500)
})

test_that("consumer file has header comments and no-calls are coded '--'", {
  f <- tempfile(fileext = ".txt")
  simulate_consumer_file(f, n_snps = 200, seed = 1, nocall_rate = 0.1)
  lines <- readLines(f)
  expect_true(any(startsWith(lines, "#")))
  expect_true(any(grepl("\t--$", lines)))
})
