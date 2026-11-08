# Lesson 31 - Consent, re-identification and genetic data
# Goal:     see why removing names does not anonymise a table, measure the risk with
#           k_anonymity(), reduce it by generalising, and see why a genotype is a fingerprint.
# Inputs:   data-sim/out/reid_register_sim.csv, data-sim/out/reid_release_sim.csv
#           (created by data-sim/extra_5.R) and data-sim/out/population_genotypes.csv
# Outputs:  output/L31_unique_vs_snps.png and small tables printed to the console
# Packages: dplyr, ggplot2
# Run from the repository root. Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.

source("R/helpers_general.R")          # gives k_anonymity(), sim_caption(), theme_cesgen()
source("data-sim/extra_5.R")           # defines ensure_extra_5_data()
library(dplyr)
library(ggplot2)

ensure_sim_data()
ensure_extra_5_data()
dir.create("output", showWarnings = FALSE)

# ---- 1. Read the "de-identified" release and the identified register -------------------
release  <- read.csv("data-sim/out/reid_release_sim.csv", stringsAsFactors = FALSE)
register <- read.csv("data-sim/out/reid_register_sim.csv", stringsAsFactors = FALSE)
stopifnot(nrow(release) == nrow(register))
stopifnot(!"person_id" %in% names(release))     # the release has no direct identifier
print(head(release))

# ---- 2. Measure the risk: how many rows are unique on the quasi-identifiers? -------------
qi <- c("sex", "birth_year", "district")
risk_before <- k_anonymity(release, qi)
print(risk_before)                               # k = smallest group size
share_unique_before <- risk_before$n_unique / nrow(release)
message("Share of rows that are unique: ", round(share_unique_before, 3))

# ---- 3. A linkage attack: join the release with the register on the quasi-identifiers ----
# For each released row, count how many register rows share the same quasi-identifiers.
# If exactly one does, the attacker knows who the row belongs to.
make_key <- function(df, cols) do.call(paste, c(df[cols], sep = "|"))
register_counts <- table(make_key(register, qi))
release$n_candidates <- as.integer(register_counts[make_key(release, qi)])
stopifnot(!any(is.na(release$n_candidates)))     # everyone in the release is in the register
release$reidentified <- release$n_candidates == 1
release$person_guess <- ifelse(release$reidentified,
                               register$person_id[match(make_key(release, qi), make_key(register, qi))],
                               NA_character_)
message("Rows re-identified by the linkage: ", sum(release$reidentified),
        " of ", nrow(release))
# The attacker now also learns the sensitive flag of each re-identified person
print(table(release$sensitive_condition[release$reidentified]))

# ---- 4. Reduce the risk by generalising the quasi-identifiers -----------------------------
# Birth year -> 10-year band; district -> five-district area. Detail is lost; k goes up.
release <- release %>%
  mutate(birth_decade = floor(birth_year / 10) * 10,
         area_group = paste0("Z", ceiling(as.integer(sub("D", "", district)) / 5)))
qi_general <- c("sex", "birth_decade", "area_group")
risk_after <- k_anonymity(release, qi_general)
print(risk_after)

privacy_table <- data.frame(
  version = c("original", "generalised"),
  k = c(risk_before$k, risk_after$k),
  n_groups = c(risk_before$n_groups, risk_after$n_groups),
  n_unique = c(risk_before$n_unique, risk_after$n_unique)
)
print(privacy_table)
stopifnot(risk_after$n_unique < risk_before$n_unique)     # generalising removed uniques
stopifnot(risk_after$n_groups < risk_before$n_groups)     # ... at the cost of detail

# ---- 5. A genotype is a fingerprint: uniqueness grows with the number of SNPs -------------
geno <- read.csv("data-sim/out/population_genotypes.csv", stringsAsFactors = FALSE)
snp_cols <- grep("^snp", names(geno), value = TRUE)
n_snps_grid <- c(1, 2, 3, 5, 8, 10, 15, 20, 30, 40)
unique_share <- sapply(n_snps_grid, function(m) {
  k_anonymity(geno, snp_cols[seq_len(m)])$n_unique / nrow(geno)
})
snp_tab <- data.frame(n_snps = n_snps_grid, share_unique = round(unique_share, 3))
print(snp_tab)
stopifnot(all(diff(unique_share) >= 0))        # adding a SNP can only split groups further

p <- ggplot(snp_tab, aes(n_snps, share_unique)) +
  geom_line(colour = cesgen_blue[["mid"]]) +
  geom_point(colour = cesgen_blue[["dark"]]) +
  labs(title = "How many SNPs make a person unique?",
       x = "Number of SNPs used", y = "Share of people with a unique profile",
       caption = sim_caption("Independent simulated SNPs; real SNPs are correlated.")) +
  theme_cesgen()
ggsave("output/L31_unique_vs_snps.png", p, width = 7, height = 4, dpi = 150)
stopifnot(file.exists("output/L31_unique_vs_snps.png"))

# ---- 6. What to take away ---------------------------------------------------------------
# * Names are only one kind of identifier; combinations of ordinary attributes also identify.
# * k_anonymity() tells you how hidden people are; generalising raises k and costs detail.
# * A handful of genetic variants is enough to single out a person in this simulation,
#   so genetic data need consent, minimisation and controlled access, not only "no names".

# EXERCISE
# 1. Find a generalisation of (sex, birth year, district) that gives k >= 5.
#    Try wider age bands (10, 20, 30 years) and coarser areas. Report the k, the number of
#    groups and what detail you lost. Expected: a table with k >= 5 and fewer categories.
# 2. Using the genotype table, find the smallest number of SNPs for which at least 95% of the
#    people have a unique profile. Expected: a number between 10 and 20 in this simulation.
# 3. Write two sentences for a data-sharing request: which columns you would release and why.
# Solutions: lessons/solutions/L31_solution.R
