# =============================================================================
# Lesson 18: Clean clinical data - dates, units, missing values and codes
# Goal:     turn a deliberately messy patient table into an analysis-ready one,
#           check the result against the known clean values, and read diagnosis codes.
# Inputs:   data-sim/out/patients_messy.csv, patients_clean.csv,
#           ehr_A_diagnoses.csv, phenotype_map.csv
# Outputs:  printed checks; output/patients_cleaned_from_messy.csv;
#           output/L18_weight_before_after.png
# Packages: readr, dplyr, stringr, lubridate, ggplot2
# Data:     Simulated data for teaching purposes. The "ICD-9" codes in the
#           simulation are invented placeholders (for example "9.PH01"), not real ICD-9 codes.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(readr)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# Month abbreviations in the file are English; make sure R reads them as such
invisible(Sys.setlocale("LC_TIME", "C"))

# -----------------------------------------------------------------------------
# 1. Read the raw file as it is (trim_ws = FALSE keeps stray spaces visible)
# -----------------------------------------------------------------------------
messy <- read_csv("data-sim/out/patients_messy.csv", show_col_types = FALSE, trim_ws = FALSE)
glimpse(messy)
cat("\nDistinct sex labels:", paste0("'", sort(unique(messy$sex)), "'", collapse = ", "), "\n")
print(table(messy$weight_unit))

# -----------------------------------------------------------------------------
# 2. Dates: three formats in one column. Detect each format, then parse each one.
# -----------------------------------------------------------------------------
parse_mixed_dates <- function(x) {
  x <- str_trim(x)
  out <- as.Date(rep(NA_character_, length(x)))
  is_iso   <- which(str_detect(x, "^\\d{4}-\\d{2}-\\d{2}$"))        # 2001-03-05
  is_slash <- which(str_detect(x, "^\\d{2}/\\d{2}/\\d{4}$"))        # 05/03/2001 (day first)
  is_words <- which(str_detect(x, "^\\d{1,2} [A-Za-z]{3} \\d{4}$")) # 05 Mar 2001
  out[is_iso]   <- ymd(x[is_iso])
  out[is_slash] <- dmy(x[is_slash])
  out[is_words] <- dmy(x[is_words])
  out
}

# -----------------------------------------------------------------------------
# 3. Sex labels: trim, lower-case, then map by the first letter
# -----------------------------------------------------------------------------
clean_sex <- function(x) {
  s <- str_to_lower(str_trim(x))
  case_when(str_starts(s, "f") ~ "F",
            str_starts(s, "m") ~ "M",
            TRUE ~ NA_character_)
}

# -----------------------------------------------------------------------------
# 4. Units and the missing-value code
# -----------------------------------------------------------------------------
lb_per_kg <- 2.20462          # pounds in one kilogram
mg_dl_per_mmol_l <- 18.016    # glucose: 1 mmol/L is about 18.016 mg/dL

reference_date <- as.Date("2026-01-01")

messy_clean <- messy %>%
  mutate(
    birth_date_clean = parse_mixed_dates(birth_date),
    sex_clean        = clean_sex(sex),
    weight_kg        = case_when(weight_unit == "kg" ~ weight,
                                 weight_unit == "lb" ~ weight / lb_per_kg,
                                 TRUE ~ NA_real_),
    glucose_mmol_l   = na_if(glucose_mmol_l, -999),
    glucose_mg_dl    = glucose_mmol_l * mg_dl_per_mmol_l,
    age_years        = as.numeric(reference_date - birth_date_clean) / 365.25
  )

# -----------------------------------------------------------------------------
# 5. Checks: never trust a cleaning step you have not verified
# -----------------------------------------------------------------------------
cat("\nDates not parsed:", sum(is.na(messy_clean$birth_date_clean) & !is.na(messy$birth_date)), "\n")
cat("Sex labels after cleaning:\n"); print(table(messy_clean$sex_clean, useNA = "ifany"))
cat("\nWeight (kg) by original unit after conversion:\n")
print(messy_clean %>% group_by(weight_unit) %>%
        summarise(n = n(), median_kg = round(median(weight_kg), 1),
                  min_kg = round(min(weight_kg), 1), max_kg = round(max(weight_kg), 1)))
cat("\nGlucose: missing after recoding =", sum(is.na(messy_clean$glucose_mmol_l)),
    "of", nrow(messy_clean), "\n")

# The simulation lets us compare with the true ages (impossible with real data)
clean_reference <- read_csv("data-sim/out/patients_clean.csv", show_col_types = FALSE)
age_check <- messy_clean %>%
  inner_join(clean_reference %>% select(patient_id, age), by = "patient_id") %>%
  mutate(age_difference = age_years - age)
cat("\nComputed age minus true age: min", round(min(age_check$age_difference), 2),
    "max", round(max(age_check$age_difference), 2), "\n")

# Does the missingness of glucose look related to anything we can see?
cat("\nGlucose missing vs observed:\n")
print(messy_clean %>%
        group_by(glucose_missing = is.na(glucose_mmol_l)) %>%
        summarise(n = n(), mean_age = round(mean(age_years), 1),
                  pct_female = round(100 * mean(sex_clean == "F"), 1)))
# Here the values were deleted at random by construction. With real data you must
# ask WHY a value is missing before choosing to drop, impute or model it.

# -----------------------------------------------------------------------------
# 6. Plot: weight before and after unit conversion
# -----------------------------------------------------------------------------
weight_long <- bind_rows(
  messy_clean %>% transmute(stage = "Raw (kg and lb mixed)", value = weight),
  messy_clean %>% transmute(stage = "Clean (kg)", value = weight_kg)
)
p_weight <- ggplot(weight_long, aes(x = value)) +
  geom_histogram(bins = 30, fill = cesgen_blue[["mid"]], colour = "white") +
  facet_wrap(~ stage, ncol = 1) +
  labs(title = "Weight before and after unit conversion", x = "Weight", y = "Patients",
       caption = sim_caption()) +
  theme_cesgen()
ggsave("output/L18_weight_before_after.png", p_weight, width = 6, height = 5, dpi = 150)

# Save the analysis-ready table
analysis_ready <- messy_clean %>%
  transmute(patient_id, birth_date = birth_date_clean, sex = sex_clean,
            weight_kg = round(weight_kg, 1), glucose_mmol_l, age_years = round(age_years, 1))
write_csv(analysis_ready, "output/patients_cleaned_from_messy.csv")

# -----------------------------------------------------------------------------
# 7. Diagnosis codes: same concept, different coding systems
# -----------------------------------------------------------------------------
diagnoses <- read_csv("data-sim/out/ehr_A_diagnoses.csv", show_col_types = FALSE)
phenotype_map <- read_csv("data-sim/out/phenotype_map.csv", show_col_types = FALSE)

cat("\nExample codes by version:\n")
print(diagnoses %>% group_by(icd_version) %>% slice_head(n = 3) %>% select(icd_version, code, phenotype_id))

# Translate each code to the phenotype group, version by version
dx_mapped <- diagnoses %>%
  mutate(phenotype_from_code = case_when(
    icd_version == 10 ~ phenotype_map$phenotype_id[match(code, phenotype_map$icd10)],
    icd_version == 9  ~ str_remove(code, "^9\\."),
    TRUE ~ NA_character_
  ))
cat("Codes that could not be mapped:", sum(is.na(dx_mapped$phenotype_from_code)), "\n")
stopifnot(all(dx_mapped$phenotype_from_code == dx_mapped$phenotype_id))

# Real-world code strings are messy too: normalise to the 3-character category
normalise_icd10 <- function(x) {
  x %>% str_to_upper() %>% str_remove_all("[^A-Z0-9]") %>% str_sub(1, 3)
}
raw_codes <- c("E11.9", "e119", " E11 ", "I10", "i10.")
print(tibble(raw = raw_codes, normalised = normalise_icd10(raw_codes)))

# -----------------------------------------------------------------------------
# 8. Sanity checks
# -----------------------------------------------------------------------------
stopifnot(!any(is.na(messy_clean$birth_date_clean)),
          all(messy_clean$sex_clean %in% c("F", "M")),
          all(messy_clean$weight_kg > 20 & messy_clean$weight_kg < 250),
          !any(messy_clean$glucose_mmol_l == -999, na.rm = TRUE),
          mean(abs(age_check$age_difference) <= 1.1) > 0.99,
          all(normalise_icd10(raw_codes) %in% c("E11", "I10")))
cat("\nL18 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Run the cleaning and confirm that the three date formats are all parsed.
# 2. Create glucose_mg_dl and check that its median is close to 18 times the
#    median of glucose_mmol_l.
# 3. Normalise these strings to ICD-10 categories with normalise_icd10():
#    "J45.0", "j450", " k21 ", "F32.9". Which diagnosis group does each belong to
#    in phenotype_map?
# Expected: no unparsed dates; ages within one year of the true age; two sex labels;
# the four codes map to J45, J45, K21 and F32 (asthma, asthma, reflux, depression).
# Worked solution: lessons/solutions/L18_solution.R
# =============================================================================
