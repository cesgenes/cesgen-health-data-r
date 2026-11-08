# =============================================================================
# Lesson 7 - Before you open a health file: practical privacy rules
# Goal:     Apply three working rules (which data to use, where to keep it, what never
#           to upload) and check a table with flag_identifier_columns() and k_anonymity().
# Inputs:   data-sim/out/patients_clean.csv, data-sim/out/patients_messy.csv,
#           and a small invented table built in this script
# Outputs:  printed checks only
# Packages: none (base R only); helpers from R/helpers_general.R
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. The toy table is invented: no real person.
# Educational material; it does not replace a health professional.
# =============================================================================

source("R/helpers_general.R")   # flag_identifier_columns(), k_anonymity()
ensure_sim_data()

# 1. The three rules, written down so you can print them for your team ------------------------
rules <- data.frame(
  rule = 1:3,
  topic = c("Which data to use", "Where to keep them", "What never to upload"),
  action = c(
    "Learn with simulated or public data; at work use only the variables the question needs, with a legal basis and approval",
    "Approved, encrypted storage with limited access; original files read-only; data outside the code repository",
    "No person-level data, not even pasted fragments, to online AI tools, cloud notebooks, web converters or public repositories"
  ),
  stringsAsFactors = FALSE
)
print(rules, row.names = FALSE)

# 2. Rule 2 in practice: is the data folder excluded from version control? ------------------------
# (Raw data should never travel with the code. This check only reads .gitignore.)
gitignore_lines <- if (file.exists(".gitignore")) readLines(".gitignore", warn = FALSE) else character(0)
patterns_to_ignore <- c("data-sim/out", ".RData", ".Rhistory")
ignored <- vapply(patterns_to_ignore, function(p) any(grepl(p, gitignore_lines, fixed = TRUE)), logical(1))
print(data.frame(pattern = patterns_to_ignore, listed_in_gitignore = unname(ignored)), row.names = FALSE)
if (!all(ignored)) {
  cat("Tip: add the folders and files that hold data or R workspaces to .gitignore.\n")
}

# 3. Rule 3 in practice: a pre-share check -----------------------------------------------------------
# flag_identifier_columns() stops with an error in the current helper version when NO column
# name matches. This small wrapper returns an empty table in that case instead.
flag_columns_safely <- function(df) {
  hits <- tryCatch(flag_identifier_columns(df), error = function(e) NULL)
  if (is.null(hits)) {
    data.frame(column = character(0), reason = character(0), stringsAsFactors = FALSE)
  } else {
    hits
  }
}

# min_k = 5 is an illustrative threshold: your data protection officer sets the real one.
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
  list(flagged = flagged, k = k_res$k, n_groups = k_res$n_groups,
       n_unique = k_res$n_unique, verdict = verdict)
}

# 4. A small INVENTED table (12 fictitious people) to see k at work ---------------------------------------
toy <- data.frame(
  patient_name = sprintf("Person %02d", 1:12),
  postcode = c("ZZ1 1AA", "ZZ1 1AB", "ZZ1 2CD", "ZZ2 3EF", "ZZ2 3EF", "ZZ2 4GH",
               "ZZ3 5JK", "ZZ3 5JK", "ZZ3 6LM", "ZZ3 6LM", "ZZ1 1AA", "ZZ2 4GH"),
  birth_year = c(1958, 1961, 1958, 1990, 1992, 1990, 1975, 1975, 1977, 1971, 1961, 1992),
  sex = c("F", "M", "F", "M", "M", "F", "F", "F", "M", "M", "M", "F"),
  glucose_mmol_l = c(5.1, 6.3, 5.8, 7.2, 5.5, 6.0, 5.2, 5.9, 6.8, 5.4, 6.1, 5.7),
  stringsAsFactors = FALSE
)
check_toy <- pre_share_check(toy, c("postcode", "birth_year", "sex"))
print(check_toy$flagged, row.names = FALSE)
cat("k =", check_toy$k, "| groups =", check_toy$n_groups, "| people alone in their group =",
    check_toy$n_unique, "\n")
cat(check_toy$verdict, "\n")

# Generalise: postcode -> area, birth year -> decade; drop the name column.
# The new columns are still quasi-identifiers: we only gave them names the
# name-based detector does not recognise, so judge them with k, not with the names.
toy_general <- data.frame(
  area = substr(toy$postcode, 1, 3),
  decade = floor(toy$birth_year / 10) * 10,
  sex = toy$sex,
  glucose_mmol_l = toy$glucose_mmol_l,
  stringsAsFactors = FALSE
)
check_general <- pre_share_check(toy_general, c("area", "decade", "sex"))
cat("After generalising: k =", check_general$k, "| people alone in their group =",
    check_general$n_unique, "\n")
cat(check_general$verdict, "\n")   # k is higher but still below 5 with only 12 people

# 5. The simulated patient files ----------------------------------------------------------------------------------
messy <- read.csv("data-sim/out/patients_messy.csv", stringsAsFactors = FALSE)
flagged_messy <- flag_columns_safely(messy)
print(flagged_messy, row.names = FALSE)   # birth_date is a quasi-identifier by its name

patients <- read.csv("data-sim/out/patients_clean.csv", stringsAsFactors = FALSE)
patients$age_band <- cut(patients$age, breaks = c(17, 39, 64, Inf),
                         labels = c("18-39", "40-64", "65+"))
k_exact <- k_anonymity(patients, c("sex", "age"))
k_band <- k_anonymity(patients, c("sex", "age_band"))
cat("Exact age + sex: k =", k_exact$k, "| people alone in their group =", k_exact$n_unique, "\n")
cat("Age band + sex:  k =", k_band$k, "| people alone in their group =", k_band$n_unique, "\n")
# patient_id is not flagged by name, but it is still an identifier: it is only a
# pseudonym if the key linking it to a person is kept apart and protected, and
# pseudonymised data are still personal data.

# 6. Sanity checks --------------------------------------------------------------------------------------------------------
stopifnot(
  nrow(rules) == 3,
  nrow(check_toy$flagged) == 3,
  check_toy$k == 1, check_toy$n_unique == 10,
  check_general$k == 2, check_general$n_unique == 0,
  "birth_date" %in% flagged_messy$column,
  k_band$k >= 5,
  k_exact$k <= k_band$k
)
cat("Lesson 7 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Run pre_share_check(patients, c("sex", "age")) and then
#    pre_share_check(patients, c("sex", "age_band")). How does k change, and what
#    verdict does each one give?
# 2. Write three sentences that apply the rules to YOUR work (which data you use,
#    where you keep them, what you never upload) and save them with writeLines()
#    to output/l07_my_data_rules.txt (create the folder with dir.create("output")).
# Expected result: with exact age, k is small (probably 1 or 2: there are very few
# people at the extreme ages); with the age band, k is in the tens or more and the
# check passes; plus a text file with your three rules.
# A worked solution is in lessons/solutions/L07_solution.R
# =============================================================================
