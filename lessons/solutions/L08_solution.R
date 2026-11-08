# =============================================================================
# Lesson 8 - Worked solution
# Task:     describe_raw_file(path) returns header lines, columns, build, strand
#           line and number of variants for a consumer-format raw file.
# Inputs:   data-sim/out/genotype_consumer_sim.txt  (SIMULATED)
# Outputs:  console only
# Packages: base R
# Run from the repository root. Simulated data for teaching purposes.
# =============================================================================

source("R/helpers_general.R")
ensure_sim_data()

describe_raw_file <- function(path) {
  stopifnot(file.exists(path))
  lines <- readLines(path)
  header <- lines[startsWith(lines, "#")]
  data <- lines[!startsWith(lines, "#")]

  # column names from the last header line
  columns <- strsplit(sub("^#\\s*", "", tail(header, 1)), "\t")[[1]]

  # build and strand come from the header text, or are reported as missing
  first_match <- function(pattern) {
    hit <- grep(pattern, header, ignore.case = TRUE, value = TRUE)
    if (length(hit) == 0) NA_character_ else hit[1]
  }
  build_line <- first_match("build|GRCh|hg19|hg38")
  build <- if (is.na(build_line)) {
    "not stated"
  } else if (grepl("GRCh37|build 37|hg19", build_line, ignore.case = TRUE)) {
    "GRCh37"
  } else if (grepl("GRCh38|build 38|hg38", build_line, ignore.case = TRUE)) {
    "GRCh38"
  } else {
    "unrecognised"
  }

  list(
    n_header_lines = length(header),
    columns = columns,
    build = build,
    strand_line = first_match("strand"),
    n_variants = length(data)
  )
}

info <- describe_raw_file("data-sim/out/genotype_consumer_sim.txt")
str(info)

stopifnot(
  info$n_header_lines == 4,
  identical(info$columns, c("rsid", "chromosome", "position", "genotype")),
  info$build == "GRCh37",
  info$n_variants == 1500
)

# If the header had no build line:
# 1. Look for the build in the provider's documentation or in the download page.
# 2. Check a few well-known variants: their positions in the file should match the
#    positions in a reference table of known build (see the allele and position
#    checks in lesson 9).
# 3. Write the build you established next to the file, and do not mix positions
#    from different builds. Joining by rsID does not depend on the build, but any
#    comparison by position does.
