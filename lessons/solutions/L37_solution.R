# Solution for lesson 37 (run from the repository root).
# It re-uses the toy package that L37_build_mini_package.R builds in tempdir().

source("lessons/L37_build_mini_package.R")   # defines `pkg_dir` when the tools are installed

if (exists("pkg_dir") && dir.exists(pkg_dir)) {
  arr_code <- r"--(
#' Absolute risk reduction from a relative risk reduction
#'
#' Multiplies a baseline risk by a relative risk reduction.
#'
#' @param baseline_risk A single number strictly between 0 and 1.
#' @param relative_risk_reduction A single number between 0 and 1 (for example,
#'   0.25 for a 25 per cent relative reduction).
#'
#' @return A single number: the absolute risk reduction, as a proportion.
#'
#' @examples
#' absolute_risk_reduction(0.10, 0.25)
#' @export
absolute_risk_reduction <- function(baseline_risk, relative_risk_reduction) {
  if (!is.numeric(baseline_risk) || length(baseline_risk) != 1L ||
      is.na(baseline_risk) || baseline_risk <= 0 || baseline_risk >= 1) {
    stop("`baseline_risk` must be a single number strictly between 0 and 1.",
         call. = FALSE)
  }
  if (!is.numeric(relative_risk_reduction) || length(relative_risk_reduction) != 1L ||
      is.na(relative_risk_reduction) ||
      relative_risk_reduction < 0 || relative_risk_reduction > 1) {
    stop("`relative_risk_reduction` must be a single number between 0 and 1.",
         call. = FALSE)
  }
  baseline_risk * relative_risk_reduction
}
)--"
  writeLines(trimws(arr_code, which = "left", whitespace = "\n"),
             file.path(pkg_dir, "R", "arr.R"))

  devtools::document(pkg_dir)
  devtools::load_all(pkg_dir)

  result <- absolute_risk_reduction(0.10, 0.25)
  print(result)
  stopifnot(
    isTRUE(all.equal(result, 0.025)),
    "export(absolute_risk_reduction)" %in% readLines(file.path(pkg_dir, "NAMESPACE")),
    file.exists(file.path(pkg_dir, "man", "absolute_risk_reduction.Rd")),
    inherits(try(absolute_risk_reduction(1.2, 0.25), silent = TRUE), "try-error")
  )
}
