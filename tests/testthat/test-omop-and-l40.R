test_that("the same cohort query gives the same people from the OMOP-like tables and the EHR", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  f <- lesson_functions("lessons/L23_query_omop_duckdb.R", "cohort_template")
  sql <- sprintf(f$cohort_template, "PH01", 1986L)
  for (site in c("A", "B")) {
    ehr <- simulate_ehr(1000, site, 2026)
    tb <- omop_like_tables(ehr)
    con <- DBI::dbConnect(duckdb::duckdb())
    for (nm in names(tb)) DBI::dbWriteTable(con, nm, tb[[nm]])
    from_sql <- DBI::dbGetQuery(con, sql)
    DBI::dbDisconnect(con, shutdown = TRUE)
    t2d <- ehr$diagnoses$patient_id[ehr$diagnoses$phenotype_id == "PH01"]
    from_ehr <- ehr$patients$patient_id[ehr$patients$age >= 40 & ehr$patients$patient_id %in% t2d]
    expect_gt(length(from_ehr), 20)
    expect_setequal(from_sql$person_source_value, from_ehr)
    # the number of records per person must also agree
    n_ehr <- table(ehr$diagnoses$patient_id[ehr$diagnoses$phenotype_id == "PH01"])
    expect_equal(from_sql$n_records, as.integer(n_ehr[from_sql$person_source_value]))
  }
  # person_id is only unique within a site
  expect_equal(omop_like_tables(simulate_ehr(50, "A"))$person$person_id,
               omop_like_tables(simulate_ehr(50, "B"))$person$person_id)
})

test_that("L40: every planted flaw is exposed in flawed_snp_analysis() and fixed in safer_snp_analysis()", {
  env <- new.env(parent = helper_env)
  lesson_functions("lessons/L40_ai_assisted_r_development.R",
                   c("with_seed", "scan_snps", "flawed_snp_analysis", "run_null_studies"), env)
  checks <- c("check_row_alignment", "check_reports_dropped_rows", "check_no_leakage",
              "check_false_positive_rate")
  lesson_functions("lessons/solutions/L40_solution.R", c(checks, "safer_snp_analysis"), env)

  p <- simulate_population(3000, 40, 2026)
  pheno <- p$pheno
  geno <- cbind(patient_id = rownames(p$geno), as.data.frame(p$geno))
  rownames(geno) <- NULL

  for (nm in checks) {
    flawed <- env[[nm]](env$flawed_snp_analysis, pheno, geno)
    safer <- env[[nm]](env$safer_snp_analysis, pheno, geno)
    expect_false(flawed$ok, info = paste("flaw not exposed by", nm, "-", flawed$detail))
    expect_true(safer$ok, info = paste("safer version fails", nm, "-", safer$detail))
  }
  # with_seed must not disturb the caller's random stream
  set.seed(1); a <- runif(1)
  set.seed(1); invisible(env$with_seed(99, runif(1))); b <- runif(1)
  expect_equal(a, b)
})

test_that("L40: the safer analysis recovers causal SNPs and gives few false positives", {
  env <- new.env(parent = helper_env)
  lesson_functions("lessons/L40_ai_assisted_r_development.R",
                   c("with_seed", "scan_snps", "run_null_studies"), env)
  lesson_functions("lessons/solutions/L40_solution.R", "safer_snp_analysis", env)
  p <- simulate_population(3000, 40, 2026)
  geno <- cbind(patient_id = rownames(p$geno), as.data.frame(p$geno))
  rownames(geno) <- NULL
  res <- env$safer_snp_analysis(p$pheno, geno)
  flagged <- res$table$snp[res$table$significant]
  expect_gte(length(intersect(flagged, p$truth$snp[p$truth$causal])), 1)
  expect_lte(length(setdiff(flagged, p$truth$snp[p$truth$causal])), 1)
})
