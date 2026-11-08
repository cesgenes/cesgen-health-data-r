# Solution for lesson 36 (run from the repository root).
# The sketch below wraps a HYPOTHETICAL analysis: from a table of odds ratios
# to a table of absolute risks. Replace it with the sketch of your own analysis.

source("R/helpers_general.R")
dir.create("output", showWarnings = FALSE)

my_sketch <- data.frame(
  fn_name = c("check_inputs()", "or_to_absolute_risk()", "plot_risk_table()", "export_table()"),
  input = c("odds ratios and a baseline risk",
            "validated odds ratios, baseline risk",
            "an absolute-risk object",
            "an absolute-risk object and an output folder"),
  output = c("TRUE, or an error that says what to fix",
             "an object with risks and differences",
             "a ggplot-like figure with the assumptions in the caption",
             "a CSV written only to the folder the user chose"),
  test_idea = c("OR <= 0 and baseline outside (0, 1) must fail",
                "OR = 1 returns the baseline; a known value (OR 2, baseline 0.1 gives 2/11)",
                "runs without error on a small example",
                "errors if no folder is given; files exist after the call in tempdir()"),
  stringsAsFactors = FALSE
)
print(my_sketch, row.names = FALSE)
stopifnot(nrow(my_sketch) >= 3, all(nzchar(unlist(my_sketch))))

# Compare the number of exports of two installed packages
exports_of <- function(pkg) length(getNamespaceExports(pkg))
comparison <- data.frame(
  package = c("stats", "nlme"),
  n_exports = c(exports_of("stats"), exports_of("nlme"))
)
print(comparison, row.names = FALSE)
stopifnot(all(comparison$n_exports > 0))
