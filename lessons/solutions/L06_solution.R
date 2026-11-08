# =============================================================================
# Lesson 6 - Worked solution of the exercise
# Goal:     Compare bin widths and two ways of showing groups; save one chart.
# Inputs:   data-sim/out/patients_clean.csv, data-sim/out/patients_messy.csv
# Outputs:  output/l06_my_chart.png
# Packages: readr, dplyr, ggplot2, stringr
# Run from the repository root.
# Simulated data for teaching purposes.
# =============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(stringr)
source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

patients <- read_csv("data-sim/out/patients_clean.csv", show_col_types = FALSE)
messy <- read_csv(
  "data-sim/out/patients_messy.csv",
  col_types = cols(.default = col_character(), weight = col_double(), glucose_mmol_l = col_double()),
  na = c("", "NA", "-999")
) |>
  mutate(sex = str_to_upper(str_sub(str_trim(sex), 1, 1))) |>
  filter(!is.na(glucose_mmol_l))

# 1. Three bin widths for the age histogram -----------------------------------------------
age_hist <- function(width) {
  ggplot(patients, aes(x = age)) +
    geom_histogram(binwidth = width, fill = cesgen_blue[["mid"]], colour = "white") +
    labs(title = paste("Age of simulated patients, bin width", width, "years"),
         x = "Age (years)", y = "Number of patients", caption = sim_caption()) +
    theme_cesgen()
}
p_w2 <- age_hist(2)     # many narrow bins: the shape is noisy
p_w5 <- age_hist(5)     # a balanced choice for 1,000 patients
p_w10 <- age_hist(10)   # few wide bins: detail is lost

# 2. Glucose by sex: facets versus fill ------------------------------------------------------------
p_facets <- ggplot(messy, aes(x = glucose_mmol_l)) +
  geom_histogram(binwidth = 0.5, fill = cesgen_blue[["mid"]], colour = "white") +
  facet_wrap(~ sex) +
  labs(title = "Glucose by sex (one panel per sex)", x = "Glucose (mmol/L)",
       y = "Number of patients", caption = sim_caption()) +
  theme_cesgen()

p_fill <- ggplot(messy, aes(x = glucose_mmol_l, fill = sex)) +
  geom_histogram(binwidth = 0.5, position = "identity", alpha = 0.6, colour = "white") +
  scale_fill_manual(values = c(F = cesgen_blue[["mid"]], M = cesgen_blue[["accent"]])) +
  labs(title = "Glucose by sex (overlaid bars)", x = "Glucose (mmol/L)",
       y = "Number of patients", fill = "Sex", caption = sim_caption()) +
  theme_cesgen()
# Facets keep each group readable; overlaid bars hide each other where they overlap.

# 3. Save the preferred version ----------------------------------------------------------------------
ggsave("output/l06_my_chart.png", plot = p_facets, width = 7, height = 4, dpi = 150)

# Sanity checks ---------------------------------------------------------------------------------------------
stopifnot(
  inherits(p_w2, "ggplot"), inherits(p_w5, "ggplot"), inherits(p_w10, "ggplot"),
  inherits(p_facets, "ggplot"), inherits(p_fill, "ggplot"),
  file.exists("output/l06_my_chart.png"),
  all(messy$sex %in% c("F", "M"))
)
cat("Solution for lesson 6 ran correctly.\n")
