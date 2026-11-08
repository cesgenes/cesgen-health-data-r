# =============================================================================
# Lesson 16: Open electronic health record sources - access and licence checklist
# Goal:     turn the "can I use this dataset?" questions into a small, reusable
#           checklist function, and record the answer for each source you consider.
# Inputs:   none (the answers are typed in by you after reading the source's pages)
# Outputs:  printed decision and checklist; output/L16_source_assessments.csv
# Packages: dplyr
# Data:     the example sources below are HYPOTHETICAL and only show how to use
#           the function. Check access and licence before using any real source.
# Educational material; it does not replace a health professional.
# Run from the repository root (RStudio project).
# =============================================================================

library(dplyr)

source("R/helpers_general.R")
dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. The checklist: eight questions, four of them critical
# -----------------------------------------------------------------------------
checklist_items <- tibble(
  item = c("access_route_known", "licence_found", "use_allowed",
           "identifiability_documented", "data_dictionary",
           "population_fits_question", "version_and_date_recorded",
           "citation_requirement_known"),
  question = c("Do I know the access route (open download, registration, credentialed access, application)?",
               "Did I find the licence or data use terms in writing?",
               "Do those terms allow my intended use (teaching, research, redistribution of results)?",
               "Is it documented whether the data are synthetic or de-identified, and how?",
               "Is there a data dictionary explaining tables, columns and codes?",
               "Do the population, country and period fit my question?",
               "Did I record the version and the date I consulted the source?",
               "Do I know how the source must be cited?"),
  critical = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE)
)

# -----------------------------------------------------------------------------
# 2. A function that turns answers ("yes", "no", "unknown") into a decision
# -----------------------------------------------------------------------------
assess_source <- function(source_name, answers) {
  stopifnot(all(checklist_items$item %in% names(answers)),
            all(answers %in% c("yes", "no", "unknown")))
  detail <- checklist_items %>%
    mutate(answer = unname(answers[item]),
           status = case_when(
             answer == "yes" ~ "ok",
             answer == "no" & critical ~ "blocker",
             answer == "unknown" & critical ~ "check first",
             TRUE ~ "note"
           ))
  decision <- if (any(detail$status == "blocker")) {
    "Do not use until the blocker is resolved"
  } else if (any(detail$status == "check first")) {
    "Check the open points before use"
  } else {
    "Can proceed (record the date and the version)"
  }
  list(source = source_name, decision = decision, detail = detail)
}

# -----------------------------------------------------------------------------
# 3. Three worked examples (hypothetical sources; answers invented to show the logic)
# -----------------------------------------------------------------------------
all_yes <- setNames(rep("yes", nrow(checklist_items)), checklist_items$item)

example_1 <- assess_source("Hypothetical synthetic dataset, fully documented", all_yes)

answers_2 <- all_yes
answers_2[c("licence_found", "use_allowed")] <- "unknown"
example_2 <- assess_source("Hypothetical dataset with no visible licence", answers_2)

answers_3 <- all_yes
answers_3["use_allowed"] <- "no"
example_3 <- assess_source("Hypothetical dataset whose terms forbid redistribution", answers_3)

for (ex in list(example_1, example_2, example_3)) {
  cat("\n", ex$source, "\n  Decision: ", ex$decision, "\n", sep = "")
}
cat("\nStatus table for the second example:\n")
print(example_2$detail %>% select(item, answer, status))

# -----------------------------------------------------------------------------
# 4. The simulated course data, assessed with the same function
# -----------------------------------------------------------------------------
course_data <- assess_source("Course simulated EHR (data-sim/00_generate_all.R)", all_yes)
cat("\n", course_data$source, "\n  Decision: ", course_data$decision, "\n", sep = "")

# -----------------------------------------------------------------------------
# 5. Keep a record: one row per source assessed
# -----------------------------------------------------------------------------
assessments <- bind_rows(lapply(list(example_1, example_2, example_3, course_data), function(a) {
  tibble(source = a$source,
         decision = a$decision,
         n_blockers = sum(a$detail$status == "blocker"),
         n_to_check = sum(a$detail$status == "check first"),
         date_checked = as.character(Sys.Date()))
}))
print(assessments)
write.csv(assessments, "output/L16_source_assessments.csv", row.names = FALSE)

# -----------------------------------------------------------------------------
# 6. Sanity checks
# -----------------------------------------------------------------------------
stopifnot(example_1$decision == "Can proceed (record the date and the version)",
          example_2$decision == "Check the open points before use",
          example_3$decision == "Do not use until the blocker is resolved",
          nrow(assessments) == 4)
cat("\nL16 finished: all sanity checks passed.\n")

# =============================================================================
# EXERCISE (Try this)
# 1. Choose ONE real candidate source (for example one of those named in the
#    lesson). Open its documentation pages and answer the eight questions with
#    "yes", "no" or "unknown". Do not guess: "unknown" is a valid answer.
# 2. Call assess_source() with your answers and read the decision.
# 3. Add the result to the assessments table and save it.
# Expected: a one-line decision and a status table; most real sources return
# "Check the open points before use" until you read their terms carefully.
# Worked solution (with placeholder answers): lessons/solutions/L16_solution.R
# =============================================================================
