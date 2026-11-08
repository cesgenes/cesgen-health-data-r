# Simulated electronic health records (EHR). Everything is invented for teaching purposes.

#' Phenotype dictionary: real ICD-10 codes grouped into simulated phenotype groups
#' (this is NOT the PheCode map; it is a small teaching map with our own group ids)
phenotype_map <- function() {
  data.frame(
    icd10 = c("E11", "E10", "I10", "I25", "F32", "F41", "J45", "J44", "N18", "K21", "K29",
              "M54", "M81", "G43", "G47", "E66", "E78", "D50", "C50", "C61", "L20", "L40",
              "H25", "H40", "N40", "N39", "O80", "Z23", "T88", "R51", "R10", "R05",
              "I48", "I50", "E03", "E05", "M06", "M10", "B20", "A09"),
    phenotype_id = sprintf("PH%02d", 1:40),
    phenotype = c("Type 2 diabetes", "Type 1 diabetes", "Hypertension", "Chronic ischaemic heart disease",
                  "Depressive episode", "Anxiety disorder", "Asthma", "COPD", "Chronic kidney disease",
                  "Reflux disease", "Gastritis", "Back pain", "Osteoporosis", "Migraine", "Sleep disorder",
                  "Obesity", "Lipid disorder", "Iron-deficiency anaemia", "Breast cancer", "Prostate cancer",
                  "Atopic dermatitis", "Psoriasis", "Cataract", "Glaucoma", "Prostate hyperplasia",
                  "Urinary tract disorder", "Delivery", "Vaccination encounter", "Procedure complication",
                  "Headache", "Abdominal pain", "Cough", "Atrial fibrillation", "Heart failure",
                  "Hypothyroidism", "Hyperthyroidism", "Rheumatoid arthritis", "Gout", "HIV disease",
                  "Gastroenteritis"),
    stringsAsFactors = FALSE
  )
}

#' Simulate one site of an EHR study with planted ("known truth") associations
#' with an adverse drug event (ADE). Truth: PH01 (OR~3.5), PH03 (OR~1.8), PH05 (OR~1.5); the rest null.
#' @param site "A" or "B"; site B has older patients and a different prevalence mix
#' @return list(patients, diagnoses, phenotypes, truth)
simulate_ehr <- function(n = 1000, site = "A", seed = 2026) {
  set.seed(seed + utf8ToInt(site))
  pm <- phenotype_map()
  age_mean <- if (site == "A") 52 else 61
  patients <- data.frame(
    patient_id = sprintf("%s%05d", site, seq_len(n)),
    site = site,
    sex = sample(c("F", "M"), n, replace = TRUE),
    age = pmin(pmax(round(rnorm(n, age_mean, 15)), 18), 95),
    stringsAsFactors = FALSE
  )
  prev <- c(0.12, 0.02, 0.25, 0.08, 0.10, 0.09, 0.08, 0.05, 0.04, 0.12, 0.06, 0.18, 0.05, 0.07, 0.10,
            0.15, 0.18, 0.06, 0.02, 0.02, 0.05, 0.03, 0.06, 0.03, 0.05, 0.08, 0.04, 0.2, 0.02, 0.1,
            0.1, 0.12, 0.04, 0.03, 0.05, 0.01, 0.01, 0.02, 0.005, 0.06)
  if (site == "B") prev <- pmin(prev * runif(40, 0.8, 1.4), 0.6)
  has <- sapply(prev, function(p) rbinom(n, 1, p))       # n x 40 matrix
  colnames(has) <- pm$phenotype_id
  lp <- -3.2 + log(3.5) * has[, "PH01"] + log(1.8) * has[, "PH03"] + log(1.5) * has[, "PH05"] +
    0.01 * (patients$age - 55)
  patients$ade <- rbinom(n, 1, plogis(lp))
  # long diagnosis table: one row per patient and code, mixing ICD-9 and ICD-10 as real systems do
  idx <- which(has == 1, arr.ind = TRUE)
  diag <- data.frame(patient_id = patients$patient_id[idx[, 1]],
                     phenotype_id = pm$phenotype_id[idx[, 2]], stringsAsFactors = FALSE)
  diag <- merge(diag, pm[, c("phenotype_id", "icd10")], by = "phenotype_id")
  diag$icd_version <- sample(c(9, 10), nrow(diag), replace = TRUE, prob = c(0.35, 0.65))
  # NOTE: the "ICD-9" labels below are invented placeholders (not real ICD-9 codes)
  diag$code <- ifelse(diag$icd_version == 10, diag$icd10, paste0("9.", diag$phenotype_id))
  diag$date <- as.Date("2018-01-01") + sample(0:2000, nrow(diag), replace = TRUE)
  diag <- diag[order(diag$patient_id, diag$date), c("patient_id", "icd_version", "code", "date", "phenotype_id")]
  rownames(diag) <- NULL
  truth <- data.frame(phenotype_id = c("PH01", "PH03", "PH05"), true_or = c(3.5, 1.8, 1.5))
  list(patients = patients, diagnoses = diag, phenotypes = pm, truth = truth)
}

#' A deliberately messy version of a patient table, for the cleaning lessons
make_messy_patients <- function(patients, seed = 2026) {
  set.seed(seed)
  n <- nrow(patients)
  dob_days <- as.numeric(as.Date("2026-01-01")) - round(patients$age * 365.25) - sample(0:364, n, replace = TRUE)
  fmt <- sample(c("%Y-%m-%d", "%d/%m/%Y", "%d %b %Y"), n, replace = TRUE)
  dob_txt <- mapply(function(d, f) format(as.Date(d, origin = "1970-01-01"), f), dob_days, fmt, USE.NAMES = FALSE)
  weight <- round(rnorm(n, 75, 14), 1)
  unit <- sample(c("kg", "kg", "kg", "lb"), n, replace = TRUE)
  weight_val <- ifelse(unit == "lb", round(weight * 2.20462, 1), weight)
  glucose <- round(rnorm(n, 5.6, 1.4), 1)
  glucose[sample(n, round(n * 0.06))] <- -999            # a typical missing-value code
  sex <- patients$sex
  sex[sample(n, round(n * 0.05))] <- sample(c("female", "Male", "m", "F "), round(n * 0.05), replace = TRUE)
  data.frame(patient_id = patients$patient_id, birth_date = dob_txt, sex = sex,
             weight = weight_val, weight_unit = unit, glucose_mmol_l = glucose,
             stringsAsFactors = FALSE)
}
