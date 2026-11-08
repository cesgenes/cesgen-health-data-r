#' Convert odds ratios into absolute risks
#'
#' Given the risk in a reference group (the baseline risk) and one or more odds
#' ratios, returns the implied absolute risks and the differences from the
#' baseline.
#'
#' The conversion works on the odds scale:
#' `odds1 = odds0 * or`, with `odds0 = baseline_risk / (1 - baseline_risk)`,
#' and the absolute risk is `odds1 / (1 + odds1)`.
#'
#' @param or Numeric vector of odds ratios. Values must be finite and
#'   strictly positive.
#' @param baseline_risk A single number strictly between 0 and 1: the risk in
#'   the reference group, as a proportion (for example, 0.1 for 10 per cent).
#'
#' @return An object of class `riskkit_risk`: a list with the input `or` and
#'   `baseline_risk`, the absolute `risk` for each odds ratio and the
#'   `difference` from the baseline risk (both as proportions).
#'
#' @examples
#' or_to_absolute_risk(c(0.5, 1, 1.5, 2), baseline_risk = 0.1)
#'
#' # The same odds ratio means different absolute changes at different baselines
#' or_to_absolute_risk(2, baseline_risk = 0.01)
#' or_to_absolute_risk(2, baseline_risk = 0.30)
#'
#' @seealso [print.riskkit_risk()]
#' @export
or_to_absolute_risk <- function(or, baseline_risk) {
  check_odds_ratio(or)
  check_baseline_risk(baseline_risk)

  odds0 <- baseline_risk / (1 - baseline_risk)
  odds1 <- odds0 * or
  risk <- odds1 / (1 + odds1)

  structure(
    list(
      or = or,
      baseline_risk = baseline_risk,
      risk = risk,
      difference = risk - baseline_risk
    ),
    class = "riskkit_risk"
  )
}

#' Print a `riskkit_risk` object
#'
#' Shows the baseline risk and a small table with the odds ratio, the implied
#' absolute risk and the difference in percentage points.
#'
#' @param x An object returned by [or_to_absolute_risk()].
#' @param digits Number of decimal places for the percentages. Default 1.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#' @export
print.riskkit_risk <- function(x, digits = 1, ...) {
  cat("Absolute risk implied by odds ratios\n")
  cat("Baseline risk: ", format(round(100 * x$baseline_risk, digits)), "%\n",
      sep = "")
  tab <- data.frame(
    odds_ratio = x$or,
    risk_pct = round(100 * x$risk, digits),
    difference_pct_points = round(100 * x$difference, digits)
  )
  print(tab, row.names = FALSE)
  cat("Illustration for teaching: not a clinical conclusion.\n")
  invisible(x)
}

# Internal validation helpers (not exported) ---------------------------------

check_odds_ratio <- function(or) {
  if (!is.numeric(or) || length(or) < 1L ||
      any(!is.finite(or)) || any(or <= 0)) {
    stop("`or` must be a numeric vector of finite, positive values.",
         call. = FALSE)
  }
  invisible(TRUE)
}

check_baseline_risk <- function(baseline_risk) {
  if (!is.numeric(baseline_risk) || length(baseline_risk) != 1L ||
      is.na(baseline_risk) || baseline_risk <= 0 || baseline_risk >= 1) {
    stop("`baseline_risk` must be a single number strictly between 0 and 1.",
         call. = FALSE)
  }
  invisible(TRUE)
}
