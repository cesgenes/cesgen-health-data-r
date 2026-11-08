# =============================================================================
# Lesson 12 - Clinical annotation: ClinVar and the ACMG secondary-findings list
# Goal:     annotate the variants of a genotyping file with a ClinVar-style table,
#           filter by clinical classification, check the secondary-findings gene
#           list, and keep a record of the version of each source.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED, not a real person)
#           A tiny hand-made TEACHING TOY table, written in this script.
# Outputs:  console tables; output/L12_toy_annotation_report.csv
# Packages: readr, dplyr
# Run from the repository root (RStudio project).
# Works OFFLINE. Simulated data for teaching purposes.
#
# IMPORTANT: the two tables below (toy_clinvar and toy_secondary_list) are NOT
# real ClinVar content and NOT the ACMG list. Gene names, variants and
# classifications are invented, so that no real result can be misread.
# Real work: use the current ClinVar release and the current ACMG list, and
# record the version and date you used (see the provenance table below).
# =============================================================================

source("R/helpers_general.R")

library(readr)
library(dplyr)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. The simulated file (see lesson 9 for the cleaning steps)
# -----------------------------------------------------------------------------
file_variants <- read_tsv(
  "data-sim/out/genotype_consumer_sim.txt",
  comment = "#",
  col_names = c("rsid", "chromosome", "position", "genotype"),
  col_types = cols(rsid = col_character(), chromosome = col_character(),
                   position = col_double(), genotype = col_character())
) %>%
  mutate(genotype = na_if(genotype, "--"))

count_allele <- function(genotype, allele) {
  allele <- rep_len(allele, length(genotype))
  vapply(seq_along(genotype), function(i) {
    if (is.na(genotype[i])) return(NA_integer_)
    sum(strsplit(genotype[i], "")[[1]] == allele[i])
  }, integer(1))
}

# -----------------------------------------------------------------------------
# 2. TEACHING TOY: a ClinVar-style table and a secondary-findings-style gene list
#    (invented content; the column names are our own)
# -----------------------------------------------------------------------------
toy_clinvar <- data.frame(
  rsid = c("sim000012", "sim000150", "sim000333", "sim000777", "sim001001", "sim001400", "sim009999"),
  toy_gene = c("GENE_A", "GENE_A", "GENE_B", "GENE_C", "GENE_D", "GENE_B", "GENE_E"),
  toy_allele = c("A", "C", "G", "T", "A", "C", "G"),
  toy_classification = c("Pathogenic", "Uncertain significance", "Likely pathogenic", "Benign",
                         "Pathogenic", "Likely benign", "Pathogenic"),
  toy_review_status = c("criteria provided, single submitter", "criteria provided, single submitter",
                        "reviewed by expert panel", "criteria provided, multiple submitters, no conflicts",
                        "no assertion criteria provided", "criteria provided, single submitter",
                        "criteria provided, single submitter"),
  stringsAsFactors = FALSE
)

toy_secondary_list <- data.frame(
  toy_gene = c("GENE_A", "GENE_B", "GENE_C"),
  toy_list_version = "toy-0.1",
  stringsAsFactors = FALSE
)
print(toy_clinvar)

# -----------------------------------------------------------------------------
# 3. Join the three sources: file, ClinVar-style table, gene list
# -----------------------------------------------------------------------------
annotated <- toy_clinvar %>%
  left_join(file_variants, by = "rsid") %>%
  left_join(toy_secondary_list, by = "toy_gene") %>%
  mutate(
    in_file = !is.na(chromosome),                     # the chip may simply not read this variant
    on_toy_list = !is.na(toy_list_version),
    allele_copies = count_allele(genotype, toy_allele),
    carries_allele = allele_copies > 0                # NA when there is no genotype
  )
print(select(annotated, rsid, toy_gene, toy_classification, genotype, in_file, on_toy_list, carries_allele))
stopifnot(nrow(annotated) == nrow(toy_clinvar), !annotated$in_file[annotated$rsid == "sim009999"])

# -----------------------------------------------------------------------------
# 4. Filter by clinical classification (the same function works on a real table
#    once you map its column names)
# -----------------------------------------------------------------------------
filter_by_classification <- function(df, column, keep) {
  df[df[[column]] %in% keep, , drop = FALSE]
}
pathogenic_terms <- c("Pathogenic", "Likely pathogenic")
plp_rows <- filter_by_classification(annotated, "toy_classification", pathogenic_terms)
cat("\nPathogenic or likely pathogenic rows in the toy table:", nrow(plp_rows), "\n")

# -----------------------------------------------------------------------------
# 5. A TEACHING RULE (not an official mapping) to attach an evidence label
# -----------------------------------------------------------------------------
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

report <- annotated %>%
  filter(in_file, carries_allele %in% TRUE) %>%
  mutate(
    evidence_label = label_variant(toy_classification, on_toy_list, toy_review_status),
    next_step = suggest_next_step(toy_classification, evidence_label)
  ) %>%
  select(rsid, toy_gene, genotype, toy_classification, toy_review_status, on_toy_list,
         evidence_label, next_step)

cat("\nVariants in the file that carry the annotated allele:\n")
print(report)
write_csv(report, "output/L12_toy_annotation_report.csv")

# A chip genotype is not a clinical test: the report is a list of candidates for a professional.
cat("\nNote: educational material; it does not replace a health professional.\n")

# -----------------------------------------------------------------------------
# 6. Provenance: what you must write down every time you use a real source
# -----------------------------------------------------------------------------
provenance <- data.frame(
  resource = c("ClinVar", "Secondary-findings gene list (ACMG)"),
  release_or_version = NA_character_,   # fill in from the source
  date_checked = NA_character_,         # fill in from the source
  where_checked = NA_character_,        # web page or file name
  stringsAsFactors = FALSE
)
print(provenance)

# -----------------------------------------------------------------------------
# 7. OPTIONAL (not run): getting real ClinVar data
# -----------------------------------------------------------------------------
# Route 1 - the ClinVar website: search by rsID or gene and read the clinical
# classification, the review status and the date of the last evaluation.
#
# Route 2 - the bulk files on the ClinVar FTP site of NCBI (check the current layout
# at source). Download the variant summary table and read it with readr:
#   clinvar_summary <- read_tsv("path/to/variant_summary.txt.gz")
#   names(clinvar_summary)    # map these column names to those used above
#
# Route 3 - NCBI's E-utilities through the rentrez package (needs internet;
# install.packages("rentrez")). This is only a sketch: check the field tags in
# ClinVar's search help before building a query.
#   library(rentrez)
#   hits <- entrez_search(db = "clinvar", term = "MTHFR[gene]", retmax = 5)
#   hits$ids
#   summaries <- entrez_summary(db = "clinvar", id = hits$ids)
#   names(summaries[[1]])     # inspect the fields before choosing what to keep
#
# Whatever the route, ClinVar classifications and the ACMG list are revised over
# time: always record the release or version and the date (table above).

# =============================================================================
# EXERCISE (Try this) - about 15 minutes
# 1. Add two rows to toy_clinvar that exist in the simulated file (for example
#    sim000200 and sim000400): a variant of uncertain significance in GENE_B, and a
#    pathogenic variant in GENE_E (a gene that is not on the toy list).
#    Re-run sections 3 to 5. Expected: the first gets "Exploratory, not actionable";
#    the second gets no evidence label and the step "Needs expert review ...".
#    (They appear in the report only if the simulated genotype carries the allele you chose.)
# 2. Fill the provenance table for the real sources you would use, leaving no NA.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L12_solution.R
# =============================================================================
