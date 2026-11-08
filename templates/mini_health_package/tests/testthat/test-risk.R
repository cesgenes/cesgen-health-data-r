test_that("an odds ratio of 1 returns the baseline risk", {
  res <- or_to_absolute_risk(1, baseline_risk = 0.2)
  expect_equal(res$risk, 0.2)
  expect_equal(res$difference, 0)
})

test_that("a known value is reproduced exactly", {
  # baseline 0.1 -> odds 1/9; OR 2 -> odds 2/9 -> risk 2/11
  res <- or_to_absolute_risk(2, baseline_risk = 0.1)
  expect_equal(res$risk, 2 / 11)
  expect_equal(res$difference, 2 / 11 - 0.1)
})

test_that("the function is vectorised over the odds ratio", {
  res <- or_to_absolute_risk(c(0.5, 1, 2), baseline_risk = 0.1)
  expect_length(res$risk, 3)
  expect_true(all(diff(res$risk) > 0))
  expect_true(all(res$risk > 0 & res$risk < 1))
})

test_that("the same odds ratio gives a larger absolute change at a higher baseline", {
  low <- or_to_absolute_risk(2, baseline_risk = 0.01)
  mid <- or_to_absolute_risk(2, baseline_risk = 0.30)
  expect_gt(mid$difference, low$difference)
})

test_that("invalid inputs fail with clear messages", {
  expect_error(or_to_absolute_risk(-1, 0.1), "positive")
  expect_error(or_to_absolute_risk(0, 0.1), "positive")
  expect_error(or_to_absolute_risk(NA_real_, 0.1), "finite")
  expect_error(or_to_absolute_risk("2", 0.1), "numeric")
  expect_error(or_to_absolute_risk(2, 0), "between 0 and 1")
  expect_error(or_to_absolute_risk(2, 1), "between 0 and 1")
  expect_error(or_to_absolute_risk(2, c(0.1, 0.2)), "single number")
})

test_that("the print method shows the baseline and returns its input invisibly", {
  res <- or_to_absolute_risk(c(1, 2), baseline_risk = 0.1)
  expect_output(print(res), "Baseline risk: 10%")
  expect_output(print(res), "not a clinical conclusion")
  expect_invisible(print(res))
})

test_that("simulated data with a known odds ratio recover that odds ratio", {
  set.seed(101)
  n <- 20000
  exposed <- rbinom(n, 1, 0.5)
  p <- or_to_absolute_risk(2, baseline_risk = 0.1)$risk
  risk <- ifelse(exposed == 1, p, 0.1)
  y <- rbinom(n, 1, risk)
  fit <- glm(y ~ exposed, family = binomial)
  # Generous tolerance on the log scale (the standard error is about 0.04)
  expect_equal(unname(coef(fit)["exposed"]), log(2), tolerance = 0.2)
})
