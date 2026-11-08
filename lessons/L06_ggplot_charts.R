# =============================================================================
# Lesson 6 - Visualising with ggplot2: clear charts for health data
# Goal:     Choose the chart that answers a question, build it with ggplot2 and
#           save it with units and data provenance.
# Inputs:   data-sim/out/patients_clean.csv, data-sim/out/patients_messy.csv
# Outputs:  output/l06_age_hist.png, l06_age_band_sex.png, l06_weight_by_sex.png,
#           l06_weight_glucose.png, l06_glucose_by_sex.png
# Packages: readr, dplyr, ggplot2, stringr
# Run from the repository root (RStudio project).
# Simulated data for teaching purposes. No real person appears in these charts.
# =============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(stringr)
source("R/helpers_general.R")   # theme_cesgen(), sim_caption(), cesgen_blue
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

# 1. Data: the same cleaning as in lesson 5, packaged as a function ------------------------
clean_messy_patients <- function(path = "data-sim/out/patients_messy.csv") {
  raw <- read_csv(
    path,
    col_types = cols(.default = col_character(), weight = col_double(), glucose_mmol_l = col_double()),
    na = c("", "NA", "-999")
  )
  raw |>
    mutate(
      sex = str_to_upper(str_sub(str_trim(sex), 1, 1)),
      weight_kg = if_else(weight_unit == "lb", round(weight * 0.45359237, 1), weight)
    ) |>
    select(patient_id, birth_date, sex, weight_kg, weight_unit, glucose_mmol_l)
}

patients <- read_csv("data-sim/out/patients_clean.csv", show_col_types = FALSE) |>
  mutate(age_band = cut(age, breaks = c(17, 39, 64, Inf), labels = c("18-39", "40-64", "65+")))
messy <- clean_messy_patients()

# 2. The question chooses the chart --------------------------------------------------------------
chart_guide <- data.frame(
  question = c("How is one numeric variable distributed?",
               "Does a numeric variable differ between groups?",
               "How many people are in each category?",
               "Do two numeric variables move together?"),
  chart = c("histogram", "box plot", "bar chart", "scatter plot"),
  geom = c("geom_histogram()", "geom_boxplot()", "geom_bar()", "geom_point()"),
  stringsAsFactors = FALSE
)
print(chart_guide)

# 3. Histogram: the distribution of age (data + aesthetics + geometry + labels + theme) -----------
p_age <- ggplot(patients, aes(x = age)) +
  geom_histogram(binwidth = 5, fill = cesgen_blue[["mid"]], colour = "white") +
  labs(
    title = paste0("Age of ", nrow(patients), " simulated patients"),
    x = "Age (years)", y = "Number of patients",
    caption = sim_caption()
  ) +
  theme_cesgen()
print(p_age)
ggsave("output/l06_age_hist.png", plot = p_age, width = 7, height = 4.5, dpi = 150)

# 4. Bars: counts of a categorical variable, split by a second one ---------------------------------
sex_colours <- c(F = cesgen_blue[["mid"]], M = cesgen_blue[["accent"]])
p_band <- ggplot(patients, aes(x = age_band, fill = sex)) +
  geom_bar(position = "dodge") +                       # bars start at zero, always
  scale_fill_manual(values = sex_colours) +
  labs(
    title = "Simulated patients by age band and sex",
    x = "Age band (years)", y = "Number of patients", fill = "Sex",
    caption = sim_caption()
  ) +
  theme_cesgen()
ggsave("output/l06_age_band_sex.png", plot = p_band, width = 7, height = 4.5, dpi = 150)

# 5. Box plot: a numeric variable compared across groups -------------------------------------------------
p_weight <- ggplot(messy, aes(x = sex, y = weight_kg)) +
  geom_boxplot(fill = cesgen_blue[["light"]]) +
  labs(
    title = "Weight by sex in the cleaned simulated table",
    x = "Sex", y = "Weight (kg)",
    caption = sim_caption()
  ) +
  theme_cesgen()
ggsave("output/l06_weight_by_sex.png", plot = p_weight, width = 6, height = 4.5, dpi = 150)

# 6. Scatter plot: two numeric variables (missing glucose values are dropped first) ---------------------------
messy_glucose <- messy |> filter(!is.na(glucose_mmol_l))
p_scatter <- ggplot(messy_glucose, aes(x = weight_kg, y = glucose_mmol_l)) +
  geom_point(alpha = 0.4, colour = cesgen_blue[["mid"]]) +
  geom_smooth(method = "lm", formula = y ~ x, colour = cesgen_blue[["accent"]]) +
  labs(
    title = "Weight and glucose in simulated patients",
    subtitle = "No relationship was built into the simulation: a flat line is the expected picture",
    x = "Weight (kg)", y = "Glucose (mmol/L)",
    caption = sim_caption()
  ) +
  theme_cesgen()
ggsave("output/l06_weight_glucose.png", plot = p_scatter, width = 7, height = 4.5, dpi = 150)

# 7. Small multiples: one panel per group with facet_wrap() ---------------------------------------------------------
p_glucose <- ggplot(messy_glucose, aes(x = glucose_mmol_l)) +
  geom_histogram(binwidth = 0.5, fill = cesgen_blue[["mid"]], colour = "white") +
  facet_wrap(~ sex) +
  labs(
    title = "Glucose by sex in simulated patients",
    x = "Glucose (mmol/L)", y = "Number of patients",
    caption = sim_caption()
  ) +
  theme_cesgen()
ggsave("output/l06_glucose_by_sex.png", plot = p_glucose, width = 7, height = 4, dpi = 150)

# 8. Sanity checks ----------------------------------------------------------------------------------------------------
figure_files <- c("output/l06_age_hist.png", "output/l06_age_band_sex.png",
                  "output/l06_weight_by_sex.png", "output/l06_weight_glucose.png",
                  "output/l06_glucose_by_sex.png")
stopifnot(
  inherits(p_age, "ggplot"), inherits(p_band, "ggplot"), inherits(p_weight, "ggplot"),
  inherits(p_scatter, "ggplot"), inherits(p_glucose, "ggplot"),
  all(file.exists(figure_files)),
  all(messy$sex %in% c("F", "M")),
  nrow(messy_glucose) < nrow(messy)
)
cat("Lesson 6 checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Change binwidth in the age histogram to 2 and then to 10. Which value shows
#    the shape of the distribution best, and why?
# 2. Draw the glucose histogram again, but fill the bars by sex instead of using
#    facet_wrap(), and compare the two versions in terms of readability.
# 3. Save your preferred version with ggsave() as output/l06_my_chart.png, with a
#    title that says what the chart shows, axes with units, and sim_caption().
# Expected result: three charts and one new PNG file in output/. The chart labels
# must include units and the note "Simulated data for teaching purposes".
# A worked solution is in lessons/solutions/L06_solution.R
# =============================================================================
