# =============================================================================
# Lesson 23: Query OMOP-like tables from R with DBI and duckdb
# Goal:     open the two simplified teaching databases (site A and site B), run ONE
#           reproducible SQL query on both, and check the cohort against the
#           EHR files used in lessons 17-21.
# Inputs:   data-sim/out/omop_site_A/*.csv and data-sim/out/omop_site_B/*.csv
#           (person, concept, condition_occurrence), plus ehr_A/B_*.csv for the check
# Outputs:  printed tables; output/L23_cohort_query.sql, output/L23_cohort_by_site.csv
# Packages: DBI, duckdb, readr, dplyr
# Data:     Simulated data for teaching purposes. These are SIMPLIFIED teaching tables
#           inspired by the OMOP common data model; they are not the full CDM and the
#           concept ids (900001-900040) are invented, not real OMOP concept ids.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(DBI)
library(duckdb)
library(readr)
library(dplyr)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Open one in-memory database per site and load its three CSV tables
# -----------------------------------------------------------------------------
load_omop_site <- function(site) {
  con <- dbConnect(duckdb::duckdb())
  folder <- file.path("data-sim", "out", paste0("omop_site_", site))
  for (tbl in c("person", "concept", "condition_occurrence")) {
    path <- file.path(folder, paste0(tbl, ".csv"))
    stopifnot(file.exists(path))
    dbExecute(con, sprintf("CREATE TABLE %s AS SELECT * FROM read_csv_auto('%s')", tbl, path))
  }
  con
}
con_a <- load_omop_site("A")
con_b <- load_omop_site("B")

cat("Tables in site A:", paste(dbListTables(con_a), collapse = ", "), "\n")
cat("Tables in site B:", paste(dbListTables(con_b), collapse = ", "), "\n")
print(dbGetQuery(con_a, "SELECT * FROM concept LIMIT 5"))
print(dbGetQuery(con_a, "SELECT * FROM person LIMIT 3"))

# person_id is only unique WITHIN a site: both sites number their people 1..1000
ids_a <- dbGetQuery(con_a, "SELECT person_id FROM person")$person_id
ids_b <- dbGetQuery(con_b, "SELECT person_id FROM person")$person_id
cat("person_id values shared by both sites:", length(intersect(ids_a, ids_b)),
    "-> always keep a site label (or person_source_value) when combining sites.\n")

# -----------------------------------------------------------------------------
# 2. The cohort definition as ONE query, parameterised and saved to a file
#    Cohort: people born in 1986 or earlier (age 40+ in 2026 in these tables)
#            with at least one type 2 diabetes record (concept code PH01)
# -----------------------------------------------------------------------------
cohort_template <- "
SELECT p.person_id,
       p.person_source_value,
       CASE p.gender_concept_id WHEN 8532 THEN 'F' WHEN 8507 THEN 'M' ELSE 'unknown' END AS sex,
       p.year_of_birth,
       MIN(co.condition_start_date) AS first_record_date,
       COUNT(*) AS n_records
FROM person AS p
JOIN condition_occurrence AS co ON co.person_id = p.person_id
JOIN concept AS c ON c.concept_id = co.condition_concept_id
WHERE c.concept_code = '%s'
  AND p.year_of_birth <= %d
GROUP BY p.person_id, p.person_source_value, p.gender_concept_id, p.year_of_birth
ORDER BY p.person_id
"
cohort_sql <- sprintf(cohort_template, "PH01", 1986L)
writeLines(cohort_sql, "output/L23_cohort_query.sql")     # the query is part of the study record

# -----------------------------------------------------------------------------
# 3. Run the very same query at both sites
# -----------------------------------------------------------------------------
cohort_a <- dbGetQuery(con_a, cohort_sql)
cohort_b <- dbGetQuery(con_b, cohort_sql)
cohort_a$site <- "A"
cohort_b$site <- "B"
cohort_all <- bind_rows(cohort_a, cohort_b)

cat("\nCohort size: site A =", nrow(cohort_a), "- site B =", nrow(cohort_b), "\n")
cat("\nSex and birth year by site:\n")
print(cohort_all %>% group_by(site) %>%
        summarise(n = n(),
                  female = sum(sex == "F"),
                  median_birth_year = median(year_of_birth)))
write.csv(cohort_all, "output/L23_cohort_by_site.csv", row.names = FALSE)

# -----------------------------------------------------------------------------
# 4. A second query: the most frequent conditions at each site (same SQL again)
# -----------------------------------------------------------------------------
top_sql <- "
SELECT c.concept_code, c.concept_name, COUNT(DISTINCT co.person_id) AS n_persons
FROM condition_occurrence AS co
JOIN concept AS c ON c.concept_id = co.condition_concept_id
GROUP BY c.concept_code, c.concept_name
ORDER BY n_persons DESC
LIMIT 5
"
cat("\nTop conditions, site A:\n"); print(dbGetQuery(con_a, top_sql))
cat("\nTop conditions, site B:\n"); print(dbGetQuery(con_b, top_sql))

# -----------------------------------------------------------------------------
# 5. Check: the query must reproduce the cohort built directly from the EHR files
# -----------------------------------------------------------------------------
cohort_from_ehr <- function(site) {
  patients <- read_csv(sprintf("data-sim/out/ehr_%s_patients.csv", site), show_col_types = FALSE)
  diagnoses <- read_csv(sprintf("data-sim/out/ehr_%s_diagnoses.csv", site), show_col_types = FALSE)
  t2d_ids <- diagnoses$patient_id[diagnoses$phenotype_id == "PH01"]
  patients$patient_id[patients$age >= 40 & patients$patient_id %in% t2d_ids]
}
ehr_ids_a <- cohort_from_ehr("A")
ehr_ids_b <- cohort_from_ehr("B")
stopifnot(setequal(cohort_a$person_source_value, ehr_ids_a),
          setequal(cohort_b$person_source_value, ehr_ids_b))
cat("\nThe SQL cohort matches the cohort built from the EHR files at both sites.\n")

# -----------------------------------------------------------------------------
# 6. Close the connections
# -----------------------------------------------------------------------------
dbDisconnect(con_a, shutdown = TRUE)
dbDisconnect(con_b, shutdown = TRUE)

stopifnot(file.exists("output/L23_cohort_query.sql"), nrow(cohort_all) > 0)
cat("\nL23 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Change the cohort: women only, born in 1976 or earlier. Hint: add a condition
#    on gender_concept_id (in these tables 8532 is female and 8507 is male) and
#    change the year in sprintf().
# 2. Run the new query on both sites and report the two cohort sizes.
# 3. Check the sizes with a direct count in R from the ehr_*_patients.csv and
#    ehr_*_diagnoses.csv files (age >= 50, sex "F", phenotype PH01).
# Expected: the SQL and the R counts agree at each site; the sizes differ between
# sites because site B is older and has a different mix of conditions.
# Worked solution: lessons/solutions/L23_solution.R
# =============================================================================
