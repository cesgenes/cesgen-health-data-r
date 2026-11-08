# =============================================================================
# Lesson 7 - Worked solution of the exercise
# Goal:     Compare k for exact age and for age band, and write your own data rules.
# Inputs:   data-sim/out/patients_clean.csv (simulated patients)
# Outputs:  output/l07_my_data_rules.txt
# Packages: none (base R only); helpers from R/helpers_general.R
# Run from the repository root.
# Simulated data for teaching purposes. Educational material; it does not replace
# a health professional.
# =============================================================================

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# A pre-share check (same logic as in the lesson script) ------------------------------------
flag_columns_safely <- function(df) {
  hits <- tryCatch(flag_identifier_columns(df), error = function(e) NULL)
  if (is.null(hits)) {
    data.frame(column = character(0), reason = character(0), stringsAsFactors = FALSE)
  } else {
    hits
  }
}
pre_share_check <- function(df, quasi_identifiers, min_k = 5) {
  flagged <- flag_columns_safely(df)
  k_res <- k_anonymity(df, quasi_identifiers)
  verdict <- if (nrow(flagged) > 0) {
    "DO NOT SHARE: columns that look like direct identifiers were found"
  } else if (k_res$k < min_k) {
    "DO NOT SHARE: some people can be singled out by their combination of data"
  } else {
    "Passes these two checks (this is not a guarantee of anonymity)"
  }
  list(flagged = flagged, k = k_res$k, n_unique = k_res$n_unique, verdict = verdict)
}

# 1. Exact age versus age band ---------------------------------------------------------------------
patients <- read.csv("data-sim/out/patients_clean.csv", stringsAsFactors = FALSE)
patients$age_band <- cut(patients$age, breaks = c(17, 39, 64, Inf),
                         labels = c("18-39", "40-64", "65+"))
check_exact <- pre_share_check(patients, c("sex", "age"))
check_band <- pre_share_check(patients, c("sex", "age_band"))
cat("Exact age: k =", check_exact$k, "|", check_exact$verdict, "\n")
cat("Age band:  k =", check_band$k, "|", check_band$verdict, "\n")

# 2. Your own three rules (edit the text for your own workplace) -------------------------------------------
my_rules <- c(
  "1. Data: I use simulated or public data to learn, and only the variables my question needs when I work with real data.",
  "2. Storage: real data stay in my institution's approved, encrypted storage, never in the code repository.",
  "3. Uploads: I never paste or upload person-level data, or a fragment of it, to an online AI tool or a cloud notebook."
)
writeLines(my_rules, "output/l07_my_data_rules.txt")

# Sanity checks ------------------------------------------------------------------------------------------------
stopifnot(
  check_exact$k <= check_band$k,
  check_band$k >= 5,
  grepl("^Passes", check_band$verdict),
  file.exists("output/l07_my_data_rules.txt"),
  length(readLines("output/l07_my_data_rules.txt")) == 3
)
cat("Solution for lesson 7 ran correctly.\n")
