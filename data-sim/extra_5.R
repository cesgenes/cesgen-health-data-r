# Extra simulated data for module 5 (lesson 31).
# Everything here is invented for teaching purposes: no real person is described.
#
# It creates two files in data-sim/out/:
#   reid_register_sim.csv  an "identified register" (person_id plus three quasi-identifiers)
#   reid_release_sim.csv   a "de-identified release" of the same people (no person_id) with a
#                          simulated sensitive condition flag, in shuffled order
#
# Usage, from the repository root:
#   source("data-sim/extra_5.R")
#   ensure_extra_5_data()

#' Simulate the register and the de-identified release
#' @param n number of people
#' @param seed random seed
#' @return list(register, release)
simulate_reid_demo <- function(n = 1500, seed = 2026) {
  set.seed(seed + 5)
  districts <- sprintf("D%02d", 1:20)
  register <- data.frame(
    person_id = sprintf("R%04d", seq_len(n)),
    sex = sample(c("F", "M"), n, replace = TRUE),
    birth_year = sample(1940:2005, n, replace = TRUE),
    # some districts are much more populated than others
    district = sample(districts, n, replace = TRUE, prob = rev(seq_along(districts))),
    stringsAsFactors = FALSE
  )
  # the release keeps the quasi-identifiers and adds a simulated sensitive flag
  release <- register[, c("sex", "birth_year", "district")]
  release$sensitive_condition <- rbinom(n, 1, 0.08)
  release <- release[sample(n), ]          # shuffle so row order does not leak identity
  rownames(release) <- NULL
  list(register = register, release = release)
}

#' Write the two files if they do not exist yet
ensure_extra_5_data <- function(dir = "data-sim/out", seed = 2026) {
  f_reg <- file.path(dir, "reid_register_sim.csv")
  f_rel <- file.path(dir, "reid_release_sim.csv")
  if (!file.exists(f_reg) || !file.exists(f_rel)) {
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    sim <- simulate_reid_demo(seed = seed)
    write.csv(sim$register, f_reg, row.names = FALSE)
    write.csv(sim$release, f_rel, row.names = FALSE)
  }
  invisible(dir)
}
