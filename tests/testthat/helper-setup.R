# Shared set-up for the tests. testthat runs each test file from tests/testthat/, so the
# repository root is found by walking up from there.
find_repo_root <- function(start = getwd()) {
  d <- normalizePath(start)
  repeat {
    if (file.exists(file.path(d, "R", "helpers_general.R")) && dir.exists(file.path(d, "lessons"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) stop("Repository root not found from ", start)
    d <- parent
  }
}
repo_root <- find_repo_root()
helper_env <- environment()

for (f in list.files(file.path(repo_root, "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(f, local = helper_env)
}
source(file.path(repo_root, "data-sim", "extra_5.R"), local = helper_env)

# Read functions that are defined inside a lesson script without running the script.
# Returns an environment holding the requested top-level `name <- function(...)` definitions.
lesson_functions <- function(file, names, env = new.env(parent = helper_env)) {
  exprs <- parse(file.path(repo_root, file))
  for (e in exprs) {
    is_assign <- is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]])
    if (is_assign && as.character(e[[2]]) %in% names) eval(e, env)
  }
  missing <- setdiff(names, ls(env))
  if (length(missing)) stop("Not found in ", file, ": ", paste(missing, collapse = ", "))
  env
}

# Phenotype indicator matrix (patients x 40) from the long diagnosis table of simulate_ehr()
pheno_matrix <- function(ehr) {
  m <- table(factor(ehr$diagnoses$patient_id, levels = ehr$patients$patient_id),
             factor(ehr$diagnoses$phenotype_id, levels = ehr$phenotypes$phenotype_id)) > 0
  storage.mode(m) <- "integer"
  m
}
