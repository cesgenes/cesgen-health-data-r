# Solution for lesson 38 (run from the repository root).
# We break the function in a COPY of the template, watch the tests fail, fix it
# and run the tests again. The template itself is never modified.

if (requireNamespace("devtools", quietly = TRUE) && requireNamespace("testthat", quietly = TRUE)) {

  template_dir <- "templates/mini_health_package"
  stopifnot(dir.exists(template_dir))

  root <- tempfile("template_copy_")
  dir.create(root)
  file.copy(template_dir, root, recursive = TRUE)
  pkg_copy <- file.path(root, "mini_health_package")
  risk_file <- file.path(pkg_copy, "R", "risk.R")

  count_failures <- function(path) {
    results <- as.data.frame(devtools::test(path, reporter = "silent"))
    sum(results$failed) + sum(results$error)
  }

  # Baseline: the template passes
  failures_before <- count_failures(pkg_copy)

  # Introduce the bug: odds are ADDED to instead of multiplied by the odds ratio
  original_lines <- readLines(risk_file)
  buggy_lines <- sub("odds1 <- odds0 \\* or", "odds1 <- odds0 + or", original_lines)
  stopifnot(!identical(original_lines, buggy_lines))   # the line was found and changed
  writeLines(buggy_lines, risk_file)
  failures_with_bug <- count_failures(pkg_copy)

  # Fix it and test again
  writeLines(original_lines, risk_file)
  failures_after_fix <- count_failures(pkg_copy)

  summary_table <- data.frame(
    state = c("original", "with the bug", "after the fix"),
    failures = c(failures_before, failures_with_bug, failures_after_fix)
  )
  print(summary_table, row.names = FALSE)
  stopifnot(failures_before == 0, failures_with_bug > 0, failures_after_fix == 0)
}
