# Solution for lesson 39 (run from the repository root).
# We add inst/CITATION to a COPY of the template and re-run the release check.

source("lessons/L39_release_checklist.R")   # defines check_release() and runs it on the template

root <- tempfile("template_copy_")
dir.create(root)
file.copy("templates/mini_health_package", root, recursive = TRUE)
pkg_copy <- file.path(root, "mini_health_package")

# A CITATION file that reads the version from DESCRIPTION (meta$Version), so it
# cannot drift out of date when the version changes
citation_text <- r"--(
bibentry(
  bibtype = "Manual",
  title = "riskkit: Small Helpers to Turn Odds Ratios into Absolute Risks",
  author = person("Course", "Author"),
  year = "2026",
  note = paste("R package version", meta$Version),
  textVersion = paste0("Author C (2026). riskkit: Small Helpers to Turn Odds Ratios ",
                       "into Absolute Risks. R package version ", meta$Version, ".")
)
)--"
dir.create(file.path(pkg_copy, "inst"), showWarnings = FALSE)
writeLines(trimws(citation_text, which = "left", whitespace = "\n"),
           file.path(pkg_copy, "inst", "CITATION"))

# The file must be readable as a citation
cit <- utils::readCitationFile(file.path(pkg_copy, "inst", "CITATION"),
                               meta = list(Version = "0.0.1"))
print(cit)

report_after <- check_release(pkg_copy)
citation_row <- report_after$files[report_after$files$item == "CITATION", c("item", "status")]
print(citation_row, row.names = FALSE)
stopifnot(citation_row$status == "ok", all(report_after$versions$agrees))
