# =============================================================================
# Lesson 37: Your first package - structure, functions and documentation
# Goal:     build a throwaway package in a temporary folder with usethis,
#           add a validated function, simulated example data and roxygen
#           documentation, then document and load it. Finally, document and
#           load the ready template in templates/mini_health_package.
# Inputs:   none (everything is created in tempdir())
# Outputs:  printed file lists, DESCRIPTION and NAMESPACE; nothing is written
#           outside the temporary folder
# Packages: usethis, devtools, roxygen2, testthat (called with ::, not
#           attached). They are not in the base course list: the script
#           stops politely if they are missing.
# Data:     SIMULATED for teaching purposes; no real people.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Are the package-building tools installed?
# -----------------------------------------------------------------------------
needed <- c("usethis", "devtools", "roxygen2", "testthat")
missing_pkgs <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  message("Missing packages: ", paste(missing_pkgs, collapse = ", "),
          ". Install them with install.packages(c(",
          paste0("\"", missing_pkgs, "\"", collapse = ", "), ")) and run again.")
} else {

  # ---------------------------------------------------------------------------
  # 2. Create the package skeleton in a temporary folder
  # ---------------------------------------------------------------------------
  pkg_dir <- file.path(tempdir(), "toypkg")
  usethis::create_package(
    pkg_dir,
    fields = list(
      Title = "A Toy Package for Body Mass Index",
      Description = paste("A throwaway package that computes body mass index",
                          "from weight and height. It exists only to practise",
                          "the package workflow. Data are simulated."),
      `Authors@R` = utils::person("Course", "Author",
                                  email = "author@example.org",
                                  role = c("aut", "cre"))
    ),
    rstudio = FALSE, open = FALSE
  )

  # usethis functions act on the "active project": run them inside with_project()
  usethis::with_project(pkg_dir, {
    usethis::use_mit_license("Course Author")
    usethis::use_testthat(3)
    usethis::use_r("bmi", open = FALSE)
  })

  # ---------------------------------------------------------------------------
  # 3. Write a function with input validation and roxygen documentation
  # ---------------------------------------------------------------------------
  bmi_code <- r"--(
#' Body mass index
#'
#' Computes body mass index (BMI) as weight in kilograms divided by the square
#' of height in metres.
#'
#' @param weight_kg Numeric vector of weights in kilograms. Must be positive.
#' @param height_m Numeric vector of heights in metres. Must be positive.
#'   Values above 3 trigger a warning because they usually mean centimetres.
#'
#' @return A numeric vector with the BMI in kg/m^2.
#'
#' @examples
#' bmi(70, 1.75)
#' bmi(c(60, 80), c(1.60, 1.85))
#'
#' @seealso [summarise_bmi()]
#' @export
bmi <- function(weight_kg, height_m) {
  if (!is.numeric(weight_kg) || !is.numeric(height_m)) {
    stop("`weight_kg` and `height_m` must be numeric.", call. = FALSE)
  }
  if (anyNA(weight_kg) || anyNA(height_m)) {
    stop("`weight_kg` and `height_m` must not contain missing values.",
         call. = FALSE)
  }
  if (any(weight_kg <= 0) || any(height_m <= 0)) {
    stop("`weight_kg` and `height_m` must be positive.", call. = FALSE)
  }
  if (any(height_m > 3)) {
    warning("`height_m` has values above 3: is the height in centimetres?",
            call. = FALSE)
  }
  weight_kg / height_m^2
}

#' Summarise a vector of BMI values
#'
#' @param bmi_values Numeric vector of BMI values, for example from [bmi()].
#'
#' @return An object of class `bmi_summary`: a list with `n`, `mean`, `sd` and
#'   `range`.
#'
#' @examples
#' summarise_bmi(bmi(c(60, 70, 80), c(1.60, 1.75, 1.85)))
#' @export
summarise_bmi <- function(bmi_values) {
  if (!is.numeric(bmi_values) || length(bmi_values) < 2L) {
    stop("`bmi_values` must be a numeric vector with at least two values.",
         call. = FALSE)
  }
  structure(
    list(
      n = length(bmi_values),
      mean = mean(bmi_values),
      sd = stats::sd(bmi_values),
      range = range(bmi_values)
    ),
    class = "bmi_summary"
  )
}

#' Print a `bmi_summary` object
#'
#' @param x An object returned by [summarise_bmi()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.bmi_summary <- function(x, ...) {
  cat("BMI summary (n =", x$n, ")\n")
  cat("  mean:  ", format(round(x$mean, 1)), "kg/m^2\n")
  cat("  sd:    ", format(round(x$sd, 1)), "\n")
  cat("  range: ", paste(format(round(x$range, 1)), collapse = " to "), "\n")
  invisible(x)
}
)--"
  writeLines(trimws(bmi_code, which = "left", whitespace = "\n"),
             file.path(pkg_dir, "R", "bmi.R"))

  # ---------------------------------------------------------------------------
  # 4. Add SIMULATED example data: the script goes in data-raw/, the result in data/
  # ---------------------------------------------------------------------------
  usethis::with_project(pkg_dir, {
    dir.create("data-raw", showWarnings = FALSE)
    writeLines(c(
      "# Simulated for teaching purposes: no real people.",
      "set.seed(2026)",
      "n <- 50",
      "height_m <- round(rnorm(n, mean = 1.70, sd = 0.08), 2)",
      "weight_kg <- round(rnorm(n, mean = 72, sd = 11), 1)",
      "toy_people <- data.frame(weight_kg = weight_kg, height_m = height_m)",
      "stopifnot(nrow(toy_people) == n, !anyNA(toy_people))",
      "usethis::use_data(toy_people, overwrite = TRUE)"
    ), file.path("data-raw", "make_toy_people.R"))
    usethis::use_build_ignore("data-raw")
    source(file.path("data-raw", "make_toy_people.R"), local = TRUE)
  })
  writeLines(c(
    "#' Simulated weights and heights (teaching data)",
    "#'",
    "#' Fifty simulated people. No real person is described.",
    "#'",
    "#' @format A data frame with 50 rows and 2 variables:",
    "#' \\describe{",
    "#'   \\item{weight_kg}{Weight in kilograms.}",
    "#'   \\item{height_m}{Height in metres.}",
    "#' }",
    "#' @source Simulated in `data-raw/make_toy_people.R`.",
    "\"toy_people\""
  ), file.path(pkg_dir, "R", "data.R"))

  # A first test, so that devtools::test() has something to run
  writeLines(c(
    "test_that(\"bmi computes weight over height squared\", {",
    "  expect_equal(bmi(70, 1.75), 70 / 1.75^2)",
    "})",
    "",
    "test_that(\"bmi rejects non-positive values with a clear message\", {",
    "  expect_error(bmi(-1, 1.75), \"positive\")",
    "})"
  ), file.path(pkg_dir, "tests", "testthat", "test-bmi.R"))

  # ---------------------------------------------------------------------------
  # 5. Turn the roxygen comments into help pages and NAMESPACE, then load
  # ---------------------------------------------------------------------------
  devtools::document(pkg_dir)
  devtools::load_all(pkg_dir)

  cat("\nFiles in the package:\n")
  print(list.files(pkg_dir, recursive = TRUE, all.files = TRUE))
  cat("\nDESCRIPTION:\n")
  writeLines(readLines(file.path(pkg_dir, "DESCRIPTION")))
  cat("\nNAMESPACE (generated by roxygen2, never edited by hand):\n")
  writeLines(readLines(file.path(pkg_dir, "NAMESPACE")))

  # Use the functions as a user would
  print(bmi(70, 1.75))
  print(summarise_bmi(bmi(toy_people$weight_kg, toy_people$height_m)))
  centimetres_warning <- tryCatch(bmi(70, 175), warning = function(w) conditionMessage(w))
  cat("Warning shown for a height in centimetres:\n ", centimetres_warning, "\n")

  # Sanity checks on the package we just built
  stopifnot(
    file.exists(file.path(pkg_dir, "man", "bmi.Rd")),
    "export(bmi)" %in% readLines(file.path(pkg_dir, "NAMESPACE")),
    "S3method(print,bmi_summary)" %in% readLines(file.path(pkg_dir, "NAMESPACE")),
    nrow(toy_people) == 50
  )
  test_results <- as.data.frame(devtools::test(pkg_dir))
  stopifnot(sum(test_results$failed) == 0, !any(test_results$error))

  # ---------------------------------------------------------------------------
  # 6. The ready template: document and load a COPY (the template stays untouched)
  # ---------------------------------------------------------------------------
  template_dir <- "templates/mini_health_package"
  if (dir.exists(template_dir)) {
    copy_root <- file.path(tempdir(), "template_copy")
    dir.create(copy_root, showWarnings = FALSE)
    file.copy(template_dir, copy_root, recursive = TRUE)
    template_copy <- file.path(copy_root, "mini_health_package")
    devtools::document(template_copy)
    devtools::load_all(template_copy)
    print(or_to_absolute_risk(c(0.5, 1, 2), baseline_risk = 0.1))
    stopifnot(file.exists(file.path(template_copy, "man", "or_to_absolute_risk.Rd")))
  } else {
    message("Template not found: run this script from the repository root.")
  }
}

# -----------------------------------------------------------------------------
# EXERCISE (Try this)
# -----------------------------------------------------------------------------
# Add a third function to the toy package (or to the copy of the template):
#   absolute_risk_reduction(baseline_risk, relative_risk_reduction)
# which returns baseline_risk * relative_risk_reduction. Give it:
#   - validation (baseline_risk strictly between 0 and 1; reduction between 0 and 1)
#   - roxygen documentation with @param, @return, @examples and @export
# Then run devtools::document() and devtools::load_all(), and check that the
# function appears in NAMESPACE and that ?absolute_risk_reduction opens a page.
# Expected result: absolute_risk_reduction(0.10, 0.25) returns 0.025.
# A worked solution is in lessons/solutions/L37_solution.R.
