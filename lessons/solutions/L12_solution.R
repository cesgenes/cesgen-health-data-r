# =============================================================================
# Lesson 12 - Worked solution
# Task:     extend the TEACHING TOY table with two rows, label them, and fill a
#           provenance record.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED) and a toy table
#           (invented content, not ClinVar and not the ACMG list)
# Outputs:  console only
# Packages: readr, dplyr
# Run from the repository root. Works offline. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
library(readr)
library(dplyr)
ensure_sim_data()

file_variants <- read_tsv(
  "data-sim/out/genotype_consumer_sim.txt",
  comment = "#",
  col_names = c("rsid", "chromosome", "position", "genotype"),
  col_types = cols(rsid = col_character(), chromosome = col_character(),
                   position = col_double(), genotype = col_character())
) %>%
  mutate(genotype = na_if(genotype, "--"))

# TOY TABLE (invented): the original rows plus the two new ones
toy_clinvar <- data.frame(
  rsid = c("sim000012", "sim000150", "sim000333", "sim000777", "sim001001", "sim001400", "sim009999",
           "sim000200", "sim000400"),
  toy_gene = c("GENE_A", "GENE_A", "GENE_B", "GENE_C", "GENE_D", "GENE_B", "GENE_E", "GENE_B", "GENE_E"),
  toy_allele = c("A", "C", "G", "T", "A", "C", "G", "A", "T"),
  toy_classification = c("Pathogenic", "Uncertain significance", "Likely pathogenic", "Benign",
                         "Pathogenic", "Likely benign", "Pathogenic",
                         "Uncertain significance", "Pathogenic"),
  toy_review_status = c("criteria provided, single submitter", "criteria provided, single submitter",
                        "reviewed by expert panel", "criteria provided, multiple submitters, no conflicts",
                        "no assertion criteria provided", "criteria provided, single submitter",
                        "criteria provided, single submitter",
                        "criteria provided, single submitter", "criteria provided, single submitter"),
  stringsAsFactors = FALSE
)
toy_secondary_list <- data.frame(toy_gene = c("GENE_A", "GENE_B", "GENE_C"),
                                 toy_list_version = "toy-0.1", stringsAsFactors = FALSE)

pathogenic_terms <- c("Pathogenic", "Likely pathogenic")
label_variant <- function(classification, on_list, review_status) {
  is_plp <- classification %in% pathogenic_terms
  weak_review <- review_status == "no assertion criteria provided"
  case_when(
    is_plp & on_list & !weak_review ~ "Established clinical application",
    classification == "Uncertain significance" ~ "Exploratory, not actionable",
    TRUE ~ NA_character_
  )
}
suggest_next_step <- function(classification, evidence_label) {
  case_when(
    !is.na(evidence_label) & evidence_label == "Established clinical application" ~
      "Candidate finding: refer for confirmation with a clinical-grade test",
    classification == "Uncertain significance" ~ "Do not act on it; the classification can change",
    classification %in% c("Likely benign", "Benign") ~ "No action",
    TRUE ~ "Needs expert review: gene not on the list or weak review status"
  )
}

# Label every annotated row (not only those carrying the allele) to see the rule at work
labelled <- toy_clinvar %>%
  left_join(toy_secondary_list, by = "toy_gene") %>%
  mutate(
    on_toy_list = !is.na(toy_list_version),
    evidence_label = label_variant(toy_classification, on_toy_list, toy_review_status),
    next_step = suggest_next_step(toy_classification, evidence_label)
  )
print(select(labelled, rsid, toy_gene, toy_classification, on_toy_list, evidence_label, next_step))

new_rows <- labelled %>% filter(rsid %in% c("sim000200", "sim000400"))
stopifnot(
  nrow(new_rows) == 2,
  new_rows$evidence_label[new_rows$rsid == "sim000200"] == "Exploratory, not actionable",
  is.na(new_rows$evidence_label[new_rows$rsid == "sim000400"]),
  grepl("Needs expert review", new_rows$next_step[new_rows$rsid == "sim000400"])
)

# Both new rsIDs exist in the simulated file; whether the person carries the allele is simulated
print(file_variants %>% filter(rsid %in% c("sim000200", "sim000400")))

# Task 2: a provenance record. Replace the placeholders with what you read at the source.
provenance <- data.frame(
  resource = c("ClinVar", "Secondary-findings gene list (ACMG)"),
  release_or_version = c("<release shown on the ClinVar page or file name>", "<version named in the publication>"),
  date_checked = as.character(Sys.Date()),
  where_checked = c("<web page or file>", "<publication or web page>"),
  stringsAsFactors = FALSE
)
print(provenance)
stopifnot(!anyNA(provenance))
