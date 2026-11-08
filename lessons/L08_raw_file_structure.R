# =============================================================================
# Lesson 8 - What a consumer genotyping file contains
# Goal:     read the structure of a raw consumer-format file: header, columns,
#           genome build, strand and special codes.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED, not a real person)
# Outputs:  console tables; output/L08_snps_per_chromosome.png
# Packages: readr, dplyr, ggplot2
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
source("R/simulate_genotypes.R")   # gives us anchor_variants(), a small reference table

library(readr)
library(dplyr)
library(ggplot2)

ensure_sim_data()                  # generates the simulated files if they are missing
dir.create("output", showWarnings = FALSE)

raw_path <- "data-sim/out/genotype_consumer_sim.txt"
stopifnot(file.exists(raw_path))

# -----------------------------------------------------------------------------
# 1. Read the file as plain text lines (no parsing yet)
# -----------------------------------------------------------------------------
raw_lines <- readLines(raw_path)
cat("Lines in the file:", length(raw_lines), "\n")

# -----------------------------------------------------------------------------
# 2. Header lines start with '#'; everything else is data
# -----------------------------------------------------------------------------
is_header <- startsWith(raw_lines, "#")
header_lines <- raw_lines[is_header]
data_lines <- raw_lines[!is_header]

cat("\nHeader lines:\n")
writeLines(header_lines)
cat("\nFirst data lines:\n")
writeLines(head(data_lines, 5))
stopifnot(length(header_lines) >= 1, length(data_lines) > 0)

# -----------------------------------------------------------------------------
# 3. Column names: in this file they sit in the last header line
# -----------------------------------------------------------------------------
last_header <- tail(header_lines, 1)
column_names <- strsplit(sub("^#\\s*", "", last_header), "\t")[[1]]
print(column_names)
stopifnot(length(column_names) == 4)

# Every data line should have the same number of tab-separated fields
fields_per_line <- lengths(strsplit(data_lines, "\t"))
print(table(fields_per_line))
stopifnot(all(fields_per_line == length(column_names)))

# -----------------------------------------------------------------------------
# 4. Genome build and strand: written in the header, never guessed
# -----------------------------------------------------------------------------
find_in_header <- function(header_lines, pattern) {
  hit <- grep(pattern, header_lines, ignore.case = TRUE, value = TRUE)
  if (length(hit) == 0) NA_character_ else hit[1]
}

detect_build <- function(text) {
  if (is.na(text)) return("not stated - find out before using positions")
  if (grepl("GRCh37|build 37|hg19", text, ignore.case = TRUE)) return("GRCh37 (build 37, hg19)")
  if (grepl("GRCh38|build 38|hg38", text, ignore.case = TRUE)) return("GRCh38 (build 38, hg38)")
  "unrecognised - read the provider documentation"
}

build_line <- find_in_header(header_lines, "build|GRCh|hg19|hg38")
strand_line <- find_in_header(header_lines, "strand")
nocall_line <- find_in_header(header_lines, "no call|no-call|nocall")

header_info <- list(
  build = detect_build(build_line),
  strand = ifelse(is.na(strand_line), "not stated", strand_line),
  no_call_note = ifelse(is.na(nocall_line), "not stated", nocall_line)
)
str(header_info)
stopifnot(grepl("GRCh37", header_info$build))

# -----------------------------------------------------------------------------
# 5. Now parse the table with readr (comment lines are skipped)
# -----------------------------------------------------------------------------
genotypes <- read_tsv(
  raw_path,
  comment = "#",
  col_names = column_names,
  col_types = cols(
    rsid = col_character(),
    chromosome = col_character(),
    position = col_double(),
    genotype = col_character()
  )
)
glimpse(genotypes)
stopifnot(nrow(genotypes) == length(data_lines))

# -----------------------------------------------------------------------------
# 6. How many variants per chromosome?
# -----------------------------------------------------------------------------
chromosome_levels <- c(as.character(1:22), "X", "Y", "MT")
snps_per_chromosome <- genotypes %>%
  count(chromosome) %>%
  mutate(chromosome = factor(chromosome, levels = chromosome_levels)) %>%
  arrange(chromosome)
print(snps_per_chromosome, n = 30)
stopifnot(!any(is.na(snps_per_chromosome$chromosome)))   # no unexpected chromosome labels

p_chr <- ggplot(snps_per_chromosome, aes(x = chromosome, y = n)) +
  geom_col(fill = cesgen_blue[["mid"]]) +
  labs(
    title = "Simulated consumer file: variants per chromosome",
    x = "Chromosome", y = "Number of variants",
    caption = sim_caption()
  ) +
  theme_cesgen()
ggsave("output/L08_snps_per_chromosome.png", p_chr, width = 8, height = 4, dpi = 150)

# -----------------------------------------------------------------------------
# 7. The shapes a genotype can take: two letters, one letter, or '--'
# -----------------------------------------------------------------------------
genotype_shapes <- genotypes %>%
  mutate(code_type = case_when(
    genotype == "--" ~ "no call",
    nchar(genotype) == 1 ~ "one letter",
    nchar(genotype) == 2 ~ "two letters",
    TRUE ~ "other"
  )) %>%
  count(code_type, is_mt = chromosome == "MT")
print(genotype_shapes)
stopifnot(all(genotype_shapes$code_type != "other"))

# In this file single letters appear only on the mitochondrial chromosome (MT).
# In real files the rule depends on the provider (for example, X and Y in males).
one_letter_outside_mt <- genotypes %>% filter(nchar(genotype) == 1, chromosome != "MT")
stopifnot(nrow(one_letter_outside_mt) == 0)

# -----------------------------------------------------------------------------
# 8. Strand: the same variant can be written with the complementary letters
# -----------------------------------------------------------------------------
complement_base <- function(x) chartr("ACGT", "TGCA", x)

strand_example <- data.frame(
  forward_strand = c("AG", "CC", "TA"),
  opposite_strand = complement_base(c("AG", "CC", "TA"))
)
print(strand_example)

# Variants whose two alleles are complements of each other (A/T or C/G) cannot be
# told apart by looking at the letters alone: they need extra information.
is_palindromic <- function(allele_1, allele_2) {
  paste0(allele_1, allele_2) %in% c("AT", "TA", "CG", "GC")
}
stopifnot(identical(is_palindromic("A", "T"), TRUE), identical(is_palindromic("A", "G"), FALSE))

anchors <- anchor_variants()
anchors$palindromic <- is_palindromic(anchors$ref, anchors$alt)
print(anchors[, c("rsid", "chromosome", "position", "ref", "alt", "palindromic")])

# The six anchor variants carry real rsIDs, but their genotypes here are simulated.
# Their coordinates belong to build 37 and should be re-checked against dbSNP.
print(genotypes %>% filter(rsid %in% anchors$rsid))

# =============================================================================
# EXERCISE (Try this) - about 15 minutes
# Write describe_raw_file(path): a function that returns a list with
#   n_header_lines, columns, build, strand_line and n_variants
# for any file written in this format. Test it on the simulated file. Expected:
# 4 header lines, the 4 column names, GRCh37 and 1500 variants.
# Then answer in a comment: what would you do if the header had no build line?
# Worked solution: lessons/solutions/L08_solution.R
# =============================================================================
