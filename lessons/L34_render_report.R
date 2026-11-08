# Lesson 34 - A reproducible report with Quarto
# Goal:     render templates/report_template.qmd in one step with the quarto R package, check
#           that the report was produced, and check that rendering twice gives the same table.
# Inputs:   templates/report_template.qmd and data-sim/out/population_pheno.csv
# Outputs:  output/health_report.html and output/report_table.csv
# Packages: quarto (needs the Quarto command-line program installed: https://quarto.org)
# Run from the repository root. Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.
#
# Alternative without R, from a terminal in the repository root:
#   quarto render templates/report_template.qmd --to html
# The HTML file appears next to the .qmd file (templates/report_template.html).

source("R/helpers_general.R")
ensure_sim_data()
dir.create("output", showWarnings = FALSE)

template <- "templates/report_template.qmd"
stopifnot(file.exists(template))

# ---- 1. Check that Quarto is available ------------------------------------------------------
quarto_ready <- requireNamespace("quarto", quietly = TRUE) && !is.null(quarto::quarto_path())
if (!quarto_ready) {
  message("Quarto is not available in this session.\n",
          "  1) Install Quarto from https://quarto.org and the R package: install.packages('quarto')\n",
          "  2) Or render from a terminal: quarto render ", template, " --to html\n",
          "Nothing was rendered; the rest of this script is skipped.")
} else {
  # ---- 2. Render the report in one step ----------------------------------------------------
  # quarto_render() runs the code, builds the tables and figures and writes the HTML file
  # next to the template. output_file is a file name, not a path.
  quarto::quarto_render(template, output_format = "html", output_file = "health_report.html")
  rendered <- file.path("templates", "health_report.html")
  stopifnot(file.exists(rendered))
  file.copy(rendered, file.path("output", "health_report.html"), overwrite = TRUE)

  # ---- 3. Check the content of the report ---------------------------------------------------
  html <- paste(readLines("output/health_report.html", warn = FALSE), collapse = "\n")
  stopifnot(grepl("Simulated data for teaching purposes", html, fixed = TRUE))
  stopifnot(grepl("Session information", html, fixed = TRUE))

  # ---- 4. Reproducibility check: render again and compare the saved table -------------------
  table_file <- file.path("output", "report_table.csv")
  stopifnot(file.exists(table_file))
  first <- unname(tools::md5sum(table_file))
  quarto::quarto_render(template, output_format = "html", output_file = "health_report.html",
                        quiet = TRUE)
  second <- unname(tools::md5sum(table_file))
  stopifnot(identical(first, second))
  message("Rendered twice: the results table is identical. Report: output/health_report.html")
}

# EXERCISE
# 1. Open templates/report_template.qmd and add one sentence under "## Results" that uses
#    inline code to state the number of people and the number of groups, for example
#    `r nrow(dat)`. Render again. Expected: the sentence shows the numbers, not the code.
# 2. In the YAML header set `echo: false` under `execute:` and render. Expected: the report
#    keeps tables and figures but hides the code. Then put it back to true.
# 3. Change the figure to show disease rate by group (a bar chart), render, and compare the two
#    HTML files. Expected: one figure changes; the table and the session information do not.
# Solutions: lessons/solutions/L34_solution.R
