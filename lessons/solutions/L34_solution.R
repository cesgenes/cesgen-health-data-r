# Lesson 34 - worked solutions
# Run from the repository root. Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

quarto_ready <- requireNamespace("quarto", quietly = TRUE) && !is.null(quarto::quarto_path())
if (!quarto_ready) {
  message("Quarto is not available: the solutions below need it. Install it from https://quarto.org")
} else {
  template <- "templates/report_template.qmd"
  lines <- readLines(template)

  # ---- Exercise 1: add a sentence with inline code under "## Results" ----------------------
  pos <- which(lines == "## Results")
  stopifnot(length(pos) == 1)
  sentence <- c("",
                "This analysis uses `r nrow(dat)` people in `r length(unique(dat$group))` groups.")
  variant <- append(lines, sentence, after = pos)

  # ---- Exercise 2: hide the code (echo: false) -----------------------------------------------
  # Work on a copy in output/ so the template stays untouched. The copy still finds the
  # repository root because the template searches upwards for R/helpers_general.R.
  variant <- sub("  echo: true", "  echo: false", variant, fixed = TRUE)
  variant_file <- file.path("output", "report_variant.qmd")
  writeLines(variant, variant_file)

  quarto::quarto_render(variant_file, output_format = "html", output_file = "report_variant.html")
  out_html <- file.path("output", "report_variant.html")
  stopifnot(file.exists(out_html))

  html <- paste(readLines(out_html, warn = FALSE), collapse = "\n")
  # The inline code was evaluated: the sentence shows the number of people, not the code
  n_people <- nrow(read.csv("data-sim/out/population_pheno.csv"))
  expected_text <- paste0("This analysis uses ", n_people, " people in 3 groups")
  stopifnot(grepl(expected_text, html, fixed = TRUE))
  message("Variant rendered: ", out_html)

  # ---- Exercise 3 (outline) -----------------------------------------------------------------
  # Replace the geom_boxplot() chunk of the template with a bar chart of disease_rate from
  # group_table, e.g. ggplot(group_table, aes(group, disease_rate)) + geom_col(). Render and
  # compare: only the figure should differ.
}
