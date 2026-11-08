# Render a template in a temporary copy that keeps the repository layout (the templates look for
# R/helpers_general.R by walking up from their own folder).
render_template_copy <- function(rel_path) {
  tmp <- tempfile("qmd"); dir.create(tmp)
  dir.create(file.path(tmp, dirname(rel_path)), recursive = TRUE)
  file.copy(file.path(repo_root, rel_path), file.path(tmp, rel_path))
  dir.create(file.path(tmp, "R"))
  file.copy(list.files(file.path(repo_root, "R"), full.names = TRUE), file.path(tmp, "R"))
  dir.create(file.path(tmp, "data-sim", "out"), recursive = TRUE)
  file.copy(list.files(file.path(repo_root, "data-sim", "out"), full.names = TRUE),
            file.path(tmp, "data-sim", "out"), recursive = TRUE)
  quarto::quarto_render(file.path(tmp, rel_path), quiet = TRUE)
  sub("[.]qmd$", ".html", file.path(tmp, rel_path))
}

test_that("the Quarto report template renders", {
  skip_if_not_installed("quarto")
  skip_if(is.null(quarto::quarto_path()), "Quarto command-line tool not installed")
  expect_true(file.exists(render_template_copy("templates/report_template.qmd")))
})

test_that("the final-project skeleton renders as it is", {
  skip_if_not_installed("quarto")
  skip_if(is.null(quarto::quarto_path()), "Quarto command-line tool not installed")
  html <- render_template_copy("templates/final_project/report_skeleton.qmd")
  expect_true(file.exists(html))
  expect_match(paste(readLines(html, warn = FALSE), collapse = " "), "Simulated data for teaching purposes")
})

test_that("mini_health_package passes document(), test() and check() in a copy", {
  skip_if_not_installed("devtools")
  skip_if(Sys.getenv("CESGEN_SKIP_PACKAGE_CHECK") == "true", "package check skipped by request")
  tmp <- tempfile("pkg"); dir.create(tmp)
  file.copy(file.path(repo_root, "templates", "mini_health_package"), tmp, recursive = TRUE)
  pkg <- file.path(tmp, "mini_health_package")
  suppressMessages(devtools::document(pkg))
  tst <- as.data.frame(suppressMessages(devtools::test(pkg, reporter = "silent")))
  expect_equal(sum(tst$failed), 0)
  expect_false(any(tst$error))
  chk <- devtools::check(pkg, args = "--no-manual", quiet = TRUE, error_on = "never")
  expect_length(chk$errors, 0)
  expect_length(chk$warnings, 0)
  expect_length(chk$notes, 0)
})

test_that("templates keep the privacy rules for AI-assisted work", {
  for (f in c("AGENTS.md", "CLAUDE.md")) {
    txt <- paste(readLines(file.path(repo_root, "templates", "ai_assisted_workflow", f)), collapse = " ")
    expect_match(txt, "real", ignore.case = TRUE)
    expect_match(txt, "credentials", ignore.case = TRUE)
  }
})
