# Solution for lesson 23 (run from the repository root).
library(DBI)
library(duckdb)
library(readr)
library(dplyr)

source("R/helpers_general.R")
ensure_sim_data()

load_omop_site <- function(site) {
  con <- dbConnect(duckdb::duckdb())
  folder <- file.path("data-sim", "out", paste0("omop_site_", site))
  for (tbl in c("person", "concept", "condition_occurrence")) {
    dbExecute(con, sprintf("CREATE TABLE %s AS SELECT * FROM read_csv_auto('%s')",
                           tbl, file.path(folder, paste0(tbl, ".csv"))))
  }
  con
}

# 1. New cohort: women born in 1976 or earlier (age 50+ in 2026) with a PH01 record
cohort_sql <- "
SELECT p.person_id, p.person_source_value, p.year_of_birth
FROM person AS p
JOIN condition_occurrence AS co ON co.person_id = p.person_id
JOIN concept AS c ON c.concept_id = co.condition_concept_id
WHERE c.concept_code = 'PH01'
  AND p.year_of_birth <= 1976
  AND p.gender_concept_id = 8532
GROUP BY p.person_id, p.person_source_value, p.year_of_birth
"

# 2. Same query, both sites
sizes <- sapply(c("A", "B"), function(site) {
  con <- load_omop_site(site)
  n <- nrow(dbGetQuery(con, cohort_sql))
  dbDisconnect(con, shutdown = TRUE)
  n
})
print(sizes)

# 3. Direct count in R from the EHR files
direct_count <- function(site) {
  patients <- read_csv(sprintf("data-sim/out/ehr_%s_patients.csv", site), show_col_types = FALSE)
  diagnoses <- read_csv(sprintf("data-sim/out/ehr_%s_diagnoses.csv", site), show_col_types = FALSE)
  t2d_ids <- diagnoses$patient_id[diagnoses$phenotype_id == "PH01"]
  sum(patients$age >= 50 & patients$sex == "F" & patients$patient_id %in% t2d_ids)
}
direct <- sapply(c("A", "B"), direct_count)
print(direct)

stopifnot(all(as.integer(sizes) == as.integer(direct)))
