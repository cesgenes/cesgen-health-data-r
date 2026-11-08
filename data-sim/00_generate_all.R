# Generates ALL simulated data used in the course. Run from the repository root:
#   source("data-sim/00_generate_all.R")
# Everything is invented for teaching purposes. A fixed seed makes the output reproducible.

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f, local = TRUE)
out <- "data-sim/out"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
seed <- 2026

# 1. Consumer genotyping file (lessons 8-9)
simulate_consumer_file(file.path(out, "genotype_consumer_sim.txt"), seed = seed)

# 2. Population with known genetic effects (lessons 10, 11, 13, 14, 32)
pop <- simulate_population(seed = seed)
write.csv(pop$pheno, file.path(out, "population_pheno.csv"), row.names = FALSE)
write.csv(cbind(patient_id = rownames(pop$geno), as.data.frame(pop$geno)),
          file.path(out, "population_genotypes.csv"), row.names = FALSE)
write.csv(pop$truth, file.path(out, "population_truth.csv"), row.names = FALSE)

# 3. EHR for two sites (lessons 15-23)
ehrA <- simulate_ehr(1000, "A", seed)
ehrB <- simulate_ehr(1000, "B", seed)
for (e in list(ehrA, ehrB)) {
  s <- e$patients$site[1]
  write.csv(e$patients, file.path(out, sprintf("ehr_%s_patients.csv", s)), row.names = FALSE)
  write.csv(e$diagnoses, file.path(out, sprintf("ehr_%s_diagnoses.csv", s)), row.names = FALSE)
}
write.csv(ehrA$phenotypes, file.path(out, "phenotype_map.csv"), row.names = FALSE)
write.csv(ehrA$truth, file.path(out, "ehr_truth.csv"), row.names = FALSE)

# 4. Small patient tables for the R basics and cleaning lessons (lessons 4-7, 18)
write.csv(ehrA$patients[, c("patient_id", "sex", "age")], file.path(out, "patients_clean.csv"), row.names = FALSE)
write.csv(make_messy_patients(ehrA$patients), file.path(out, "patients_messy.csv"), row.names = FALSE)

# 5. OMOP-like tables for two sites (lesson 23)
for (e in list(ehrA, ehrB)) {
  s <- e$patients$site[1]
  tb <- omop_like_tables(e)
  d <- file.path(out, paste0("omop_site_", s)); dir.create(d, showWarnings = FALSE)
  for (nm in names(tb)) write.csv(tb[[nm]], file.path(d, paste0(nm, ".csv")), row.names = FALSE)
}

# 6. Small areas with exposure and deprivation (lessons 24-30); needs sf
if (requireNamespace("sf", quietly = TRUE)) {
  areas <- simulate_areas(seed = seed)
  sf::st_write(areas, file.path(out, "areas_sim.gpkg"), delete_dsn = TRUE, quiet = TRUE)
  write.csv(sf::st_drop_geometry(areas), file.path(out, "areas_sim_attributes.csv"), row.names = FALSE)
} else {
  message("Package 'sf' not installed: skipping the spatial data (needed from lesson 25).")
}
writeLines(generator_fingerprint(), file.path(out, ".generator_stamp"))   # lets ensure_sim_data() detect stale data
message("Simulated data written to ", out)
