# =============================================================================
# Lesson 9 - Worked solution
# Task:     call rate by chromosome and detection of a strand-flipped genotype.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED)
# Outputs:  console only
# Packages: readr, dplyr
# Run from the repository root. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
source("R/simulate_genotypes.R")
library(readr)
library(dplyr)
ensure_sim_data()

raw <- read_tsv(
  "data-sim/out/genotype_consumer_sim.txt",
  comment = "#",
  col_names = c("rsid", "chromosome", "position", "genotype"),
  col_types = cols(rsid = col_character(), chromosome = col_character(),
                   position = col_double(), genotype = col_character())
)

clean <- raw %>%
  mutate(
    call_type = if_else(genotype == "--", "no_call", "called"),
    genotype_clean = if_else(genotype == "--", NA_character_, genotype)
  )

# Task 1 -------------------------------------------------------------------
call_rate_by_chromosome <- function(df) {
  df %>%
    group_by(chromosome) %>%
    summarise(n = n(), call_rate = mean(call_type != "no_call"), .groups = "drop") %>%
    arrange(desc(n))
}
rates <- call_rate_by_chromosome(clean)
print(rates, n = 30)
stopifnot(all(rates$call_rate > 0.8), rates$chromosome[nrow(rates)] %in% c("MT", "X"))

# Task 2 -------------------------------------------------------------------
alleles_match <- function(genotype, ref, alt) {
  vapply(seq_along(genotype), function(i) {
    if (is.na(genotype[i])) return(NA)
    all(strsplit(genotype[i], "")[[1]] %in% c(ref[i], alt[i]))
  }, logical(1))
}

lactase_snp <- clean %>%
  filter(rsid == "rs4988235") %>%
  inner_join(anchor_variants(), by = "rsid", suffix = c("", "_ref")) %>%
  mutate(genotype_flipped = chartr("ACGT", "TGCA", genotype_clean))

original_ok <- alleles_match(lactase_snp$genotype_clean, lactase_snp$ref, lactase_snp$alt)
flipped_ok <- alleles_match(lactase_snp$genotype_flipped, lactase_snp$ref, lactase_snp$alt)
print(data.frame(original = lactase_snp$genotype_clean, flipped = lactase_snp$genotype_flipped,
                 original_ok, flipped_ok))

# If this variant happened to be a no-call in the simulated file, both checks are NA:
# the check needs a called genotype.
stopifnot(is.na(original_ok) || (original_ok && !flipped_ok))
