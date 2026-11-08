# =============================================================================
# Lesson 9 - Read and clean a genotyping file in R
# Goal:     import a consumer-format file, turn no-calls into missing values,
#           handle single-letter genotypes (MT) and run quality checks.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED, not a real person)
# Outputs:  output/L09_genotypes_clean.csv, output/L09_call_rate_by_chromosome.png
# Packages: readr, dplyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
source("R/simulate_genotypes.R")   # anchor_variants(): reference alleles and positions (build 37)

library(readr)
library(dplyr)
library(ggplot2)

ensure_sim_data()
dir.create("output", showWarnings = FALSE)

raw_path <- "data-sim/out/genotype_consumer_sim.txt"

# -----------------------------------------------------------------------------
# 1. Import: skip the '#' header lines and name the columns ourselves
# -----------------------------------------------------------------------------
raw <- read_tsv(
  raw_path,
  comment = "#",
  col_names = c("rsid", "chromosome", "position", "genotype"),
  col_types = cols(
    rsid = col_character(),
    chromosome = col_character(),
    position = col_double(),
    genotype = col_character()
  )
)
stopifnot(nrow(readr::problems(raw)) == 0)   # readr found nothing it could not parse
glimpse(raw)

# -----------------------------------------------------------------------------
# 2. Classify each call: no call, one letter, two letters
# -----------------------------------------------------------------------------
calls <- raw %>%
  mutate(
    call_type = case_when(
      genotype == "--" ~ "no_call",
      nchar(genotype) == 1 ~ "one_allele",
      nchar(genotype) == 2 ~ "two_alleles",
      TRUE ~ "unexpected"
    ),
    # a no-call is missing information, not a genotype: it becomes NA
    genotype_clean = if_else(call_type == "no_call", NA_character_, genotype)
  )
print(count(calls, call_type))
stopifnot(!any(calls$call_type == "unexpected"))

# -----------------------------------------------------------------------------
# 3. Validity checks: letters and number of alleles
# -----------------------------------------------------------------------------
valid_letters <- is.na(calls$genotype_clean) | grepl("^[ACGT]{1,2}$", calls$genotype_clean)
stopifnot(all(valid_letters))

# MT is haploid: one letter. Autosomes: two letters.
bad_ploidy <- calls %>%
  filter(!is.na(genotype_clean)) %>%
  filter((chromosome == "MT" & nchar(genotype_clean) != 1) |
           (chromosome %in% as.character(1:22) & nchar(genotype_clean) != 2))
stopifnot(nrow(bad_ploidy) == 0)

# -----------------------------------------------------------------------------
# 4. Normalise the order of the letters and split the two alleles
# -----------------------------------------------------------------------------
normalise_genotype <- function(x) {
  vapply(x, function(g) {
    if (is.na(g)) return(NA_character_)
    paste(sort(strsplit(g, "")[[1]]), collapse = "")
  }, character(1), USE.NAMES = FALSE)
}
stopifnot(identical(normalise_genotype(c("GA", "AG", NA, "T")), c("AG", "AG", NA, "T")))

clean <- calls %>%
  mutate(
    genotype_clean = normalise_genotype(genotype_clean),
    allele_1 = substr(genotype_clean, 1, 1),
    allele_2 = na_if(substr(genotype_clean, 2, 2), ""),
    # NA when there is a single allele or no call
    is_heterozygous = allele_1 != allele_2
  )

# -----------------------------------------------------------------------------
# 5. Quality summary
# -----------------------------------------------------------------------------
qc_overall <- clean %>%
  summarise(
    n_variants = n(),
    n_no_call = sum(call_type == "no_call"),
    call_rate = mean(call_type != "no_call"),
    n_duplicated_rsid = sum(duplicated(rsid))
  )
print(qc_overall)
stopifnot(qc_overall$n_duplicated_rsid == 0, qc_overall$call_rate > 0.9)

chromosome_levels <- c(as.character(1:22), "X", "Y", "MT")
qc_by_chromosome <- clean %>%
  group_by(chromosome) %>%
  summarise(n = n(), call_rate = mean(call_type != "no_call"), .groups = "drop") %>%
  mutate(chromosome = factor(chromosome, levels = chromosome_levels)) %>%
  arrange(chromosome)
print(qc_by_chromosome, n = 30)

# Heterozygosity on the autosomes: a very low or very high value can flag a problem
het_rate <- clean %>%
  filter(chromosome %in% as.character(1:22), !is.na(is_heterozygous)) %>%
  summarise(het_rate = mean(is_heterozygous))
print(het_rate)
stopifnot(het_rate$het_rate > 0, het_rate$het_rate < 1)

p_call <- ggplot(qc_by_chromosome, aes(x = chromosome, y = call_rate, size = n)) +
  geom_point(colour = cesgen_blue[["mid"]]) +
  scale_y_continuous(limits = c(0.9, 1)) +
  labs(
    title = "Call rate per chromosome (simulated file)",
    x = "Chromosome", y = "Call rate", size = "Variants",
    caption = sim_caption("Axis starts at 0.9 to make small differences visible.")
  ) +
  theme_cesgen()
ggsave("output/L09_call_rate_by_chromosome.png", p_call, width = 8, height = 4, dpi = 150)

# -----------------------------------------------------------------------------
# 6. Do the alleles and positions agree with a reference table?
#    (only possible for variants that are in the reference table: the six anchors)
# -----------------------------------------------------------------------------
alleles_match <- function(genotype, ref, alt) {
  vapply(seq_along(genotype), function(i) {
    if (is.na(genotype[i])) return(NA)
    all(strsplit(genotype[i], "")[[1]] %in% c(ref[i], alt[i]))
  }, logical(1))
}

anchor_check <- clean %>%
  inner_join(anchor_variants(), by = "rsid", suffix = c("", "_ref")) %>%
  mutate(
    alleles_ok = alleles_match(genotype_clean, ref, alt),
    position_ok = position == position_ref
  ) %>%
  select(rsid, chromosome, position, position_ref, genotype_clean, ref, alt, alleles_ok, position_ok)
print(anchor_check)
stopifnot(nrow(anchor_check) == 6, all(anchor_check$alleles_ok, na.rm = TRUE), all(anchor_check$position_ok))

# What a strand mismatch looks like: write the same genotypes on the opposite strand
flipped <- anchor_check %>%
  mutate(
    genotype_flipped = chartr("ACGT", "TGCA", genotype_clean),
    flipped_ok = alleles_match(genotype_flipped, ref, alt)
  ) %>%
  select(rsid, genotype_clean, genotype_flipped, ref, alt, flipped_ok)
print(flipped)
# None of the six anchors is palindromic (A/T or C/G), so the mismatch is detectable
stopifnot(all(!flipped$flipped_ok, na.rm = TRUE))

# -----------------------------------------------------------------------------
# 7. Save the clean table (no-calls removed, and counted above) and keep the raw file untouched
# -----------------------------------------------------------------------------
clean_calls <- clean %>%
  filter(call_type != "no_call") %>%
  select(rsid, chromosome, position, genotype = genotype_clean, allele_1, allele_2)
write_csv(clean_calls, "output/L09_genotypes_clean.csv")
stopifnot(nrow(clean_calls) == qc_overall$n_variants - qc_overall$n_no_call)
cat("Clean table:", nrow(clean_calls), "variants with a call;",
    qc_overall$n_no_call, "no-calls set aside.\n")

# =============================================================================
# EXERCISE (Try this) - about 15 minutes
# 1. Write call_rate_by_chromosome(df): given the 'clean' table, return one row per
#    chromosome with the number of variants and the call rate.
#    Expected: call rates close to 1 for every chromosome; MT has the fewest variants.
# 2. Take rs4988235 from the clean table, write its genotype on the opposite strand
#    with chartr(), and show that alleles_match() flags it as inconsistent.
#    Expected: alleles_ok is TRUE for the original and FALSE for the flipped copy.
# Material for educational use; it does not replace a health professional.
# Worked solution: lessons/solutions/L09_solution.R
# =============================================================================
