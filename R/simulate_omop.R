# A tiny OMOP-like database for teaching (2 sites with different local structures).
# This is a simplified, simulated model inspired by the OMOP CDM: it is NOT a full CDM.

#' Build the common-model tables for one site from the simulated EHR
#' Site A stores ICD-10 codes directly; site B stores local codes mapped through a source-to-concept table.
omop_like_tables <- function(ehr) {
  pm <- ehr$phenotypes
  person <- data.frame(person_id = seq_len(nrow(ehr$patients)),
                       person_source_value = ehr$patients$patient_id,
                       gender_concept_id = ifelse(ehr$patients$sex == "F", 8532L, 8507L),
                       year_of_birth = 2026L - as.integer(ehr$patients$age),
                       stringsAsFactors = FALSE)
  # concept table: our own teaching concept ids (not real OMOP concept ids)
  concept <- data.frame(concept_id = 900000L + seq_len(nrow(pm)),
                        concept_name = pm$phenotype, vocabulary_id = "TEACHING",
                        concept_code = pm$phenotype_id, stringsAsFactors = FALSE)
  d <- ehr$diagnoses
  d$person_id <- person$person_id[match(d$patient_id, person$person_source_value)]
  d$condition_concept_id <- concept$concept_id[match(d$phenotype_id, concept$concept_code)]
  condition_occurrence <- data.frame(condition_occurrence_id = seq_len(nrow(d)),
                                     person_id = d$person_id,
                                     condition_concept_id = d$condition_concept_id,
                                     condition_start_date = d$date,
                                     condition_source_value = d$code, stringsAsFactors = FALSE)
  list(person = person, condition_occurrence = condition_occurrence, concept = concept)
}
