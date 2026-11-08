# General helpers shared by all lessons.
# All data used in this repository are SIMULATED for teaching purposes.

cesgen_blue <- c(dark = "#0F3563", mid = "#1E63B0", light = "#7FB0E0", grey = "#6B7785", accent = "#D9822B")

#' ggplot2 theme used across the course
theme_cesgen <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", colour = cesgen_blue[["dark"]]),
      plot.caption = ggplot2::element_text(colour = cesgen_blue[["grey"]], hjust = 0),
      panel.grid.minor = ggplot2::element_blank()
    )
}

#' Standard caption for simulated data
sim_caption <- function(extra = NULL) {
  paste(c("Simulated data for teaching purposes. Prepared by CESGEN.", extra), collapse = " ")
}

#' Convert an odds ratio into an absolute risk, given a baseline risk
#' @param or odds ratio (relative to the baseline group)
#' @param baseline_risk risk in the baseline group (between 0 and 1)
or_to_absolute_risk <- function(or, baseline_risk) {
  stopifnot(all(baseline_risk > 0 & baseline_risk < 1), all(or > 0))
  odds0 <- baseline_risk / (1 - baseline_risk)
  odds1 <- odds0 * or
  odds1 / (1 + odds1)
}

#' Odds ratio with 95% CI (Wald) for one term of a glm
tidy_or <- function(model, term) {
  co <- summary(model)$coefficients
  if (!term %in% rownames(co)) {
    return(data.frame(term = term, or = NA_real_, lower = NA_real_, upper = NA_real_, p_value = NA_real_))
  }
  est <- co[term, "Estimate"]; se <- co[term, "Std. Error"]
  data.frame(term = term, or = exp(est), lower = exp(est - 1.96 * se),
             upper = exp(est + 1.96 * se), p_value = co[term, ncol(co)])
}

#' Bonferroni threshold
bonferroni_threshold <- function(n_tests, alpha = 0.05) alpha / n_tests

#' Flag columns that look like direct identifiers (used in lesson 7)
flag_identifier_columns <- function(df) {
  pattern <- "name|surname|email|phone|address|postcode|zip|nhs|dni|nie|passport|dob|birth|ssn|mrn"
  hits <- grep(pattern, names(df), ignore.case = TRUE, value = TRUE)
  data.frame(column = hits,
             reason = rep("name looks like a direct identifier or quasi-identifier", length(hits)),
             stringsAsFactors = FALSE)
}

#' Smallest group size over a set of quasi-identifiers (k in k-anonymity)
k_anonymity <- function(df, quasi_identifiers) {
  stopifnot(all(quasi_identifiers %in% names(df)))
  counts <- table(do.call(paste, c(df[quasi_identifiers], sep = "|")))
  list(k = min(counts), n_groups = length(counts), n_unique = sum(counts == 1))
}

#' Fingerprint of the files that generate the simulated data (a change in any of them changes it)
generator_fingerprint <- function() {
  files <- sort(c(list.files("R", pattern = "^simulate_.*[.]R$", full.names = TRUE),
                  list.files("data-sim", pattern = "[.]R$", full.names = TRUE)))
  paste(unname(tools::md5sum(files)), collapse = "")
}

#' Make sure the simulated data exist and were made by the current generator code.
#' If the folder is missing, incomplete, or was made by older generator code, it is rebuilt.
ensure_sim_data <- function(dir = "data-sim/out", quiet = FALSE) {
  # The generator always writes to data-sim/out with its own fixed seed (2026).
  if (!identical(dir, "data-sim/out")) {
    stop("ensure_sim_data() only supports the default folder \"data-sim/out\".", call. = FALSE)
  }
  marker <- file.path(dir, "patients_clean.csv")
  stamp <- file.path(dir, ".generator_stamp")
  current <- file.exists(marker) && file.exists(stamp) &&
    identical(readLines(stamp, warn = FALSE), generator_fingerprint())
  if (!current) {
    if (!quiet) message("Generating simulated data in ", dir, " ...")
    unlink(dir, recursive = TRUE)
    source("data-sim/00_generate_all.R", local = new.env())
  }
  invisible(dir)
}
