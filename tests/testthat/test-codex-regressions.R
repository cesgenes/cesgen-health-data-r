# Regression tests for the findings of the first independent review (reviews/).

test_that("run_phewas does not report an odds ratio when the exposed group has no events", {
  f <- lesson_functions("lessons/L21_phewas_run.R", "run_phewas")
  suppressMessages(library(purrr)); suppressMessages(library(dplyr))
  environment(f$run_phewas) <- list2env(list(map_dfr = purrr::map_dfr, tidy_or = tidy_or), parent = globalenv())
  # 10 exposed patients, none with the event (the case that gave OR = 6e-23, upper = Inf)
  d <- data.frame(ade = c(rep(0, 10), rep(c(0, 1), 15)), age = rep(40:59, 2),
                  sex = rep(c("F", "M"), 20), PHX = c(rep(1, 10), rep(0, 30)))
  r <- f$run_phewas(d, "PHX", min_exposed = 10)
  expect_true(is.na(r$or) && is.na(r$p_value))
  expect_equal(r$status, "too few events or non-events")
  expect_equal(r$n_exposed, 10)
  # a well-supported phenotype is still fitted
  set.seed(5)
  n <- 4000
  d2 <- data.frame(age = sample(30:80, n, TRUE), sex = sample(c("F", "M"), n, TRUE),
                   PHY = rbinom(n, 1, 0.2))
  d2$ade <- rbinom(n, 1, plogis(-2.5 + log(2) * d2$PHY))
  r2 <- f$run_phewas(d2, "PHY")
  expect_equal(r2$status, "fitted")
  expect_gt(r2$or, 1.5); expect_lt(r2$or, 2.7)
  # too few exposed patients
  expect_equal(f$run_phewas(transform(d2, PHY = as.integer(seq_len(n) <= 4)), "PHY")$status,
               "too few exposed")
})

test_that("on the shipped simulated sites no tested phenotype has a degenerate odds ratio", {
  f <- lesson_functions("lessons/L21_phewas_run.R", "run_phewas")
  suppressMessages(library(purrr)); suppressMessages(library(dplyr))
  environment(f$run_phewas) <- list2env(list(map_dfr = purrr::map_dfr, tidy_or = tidy_or), parent = globalenv())
  for (site in c("A", "B")) {
    e <- simulate_ehr(1000, site, 2026)
    wide <- cbind(e$patients[c("sex", "age", "ade")], as.data.frame(pheno_matrix(e)))
    res <- f$run_phewas(wide, e$phenotypes$phenotype_id)
    tested <- res[!is.na(res$p_value), ]
    expect_gt(nrow(tested), 20)
    expect_true(all(is.finite(tested$lower) & is.finite(tested$upper) & tested$or > 0.05 & tested$or < 50))
    expect_true(all(res$status[is.na(res$p_value)] != "fitted"))
  }
})

test_that("ensure_sim_data rebuilds data made by older generator code", {
  skip_if_not_installed("sf")
  tmp <- tempfile("repo"); dir.create(tmp)
  file.copy(file.path(repo_root, "R"), tmp, recursive = TRUE)
  dir.create(file.path(tmp, "data-sim"))
  file.copy(list.files(file.path(repo_root, "data-sim"), pattern = "[.]R$", full.names = TRUE),
            file.path(tmp, "data-sim"))
  withr::with_dir(tmp, {
    ensure_sim_data(quiet = TRUE)
    stamp <- readLines("data-sim/out/.generator_stamp")
    expect_identical(stamp, generator_fingerprint())
    # a stale leftover file disappears only if the folder is rebuilt
    writeLines("stale", "data-sim/out/leftover.csv")
    ensure_sim_data(quiet = TRUE)
    expect_true(file.exists("data-sim/out/leftover.csv"))          # up to date: untouched
    cat("\n# changed generator\n", file = "R/simulate_omop.R", append = TRUE)
    ensure_sim_data(quiet = TRUE)
    expect_false(file.exists("data-sim/out/leftover.csv"))         # outdated: rebuilt from scratch
    expect_true(file.exists("data-sim/out/patients_clean.csv"))
    expect_false(identical(readLines("data-sim/out/.generator_stamp"), stamp))
  })
})
