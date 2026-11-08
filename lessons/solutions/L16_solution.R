# Solution for lesson 16 (run from the repository root).
# The answers below are PLACEHOLDERS: replace them with what you find in the
# documentation of the source you chose. Check access and licence before use.
library(dplyr)

source("R/helpers_general.R")
# Re-use the checklist and the function defined in L16_source_checklist.R, without
# re-running its examples: copy the two definitions or source the whole script.
source("lessons/L16_source_checklist.R")

my_answers <- c(access_route_known = "yes",
                licence_found = "unknown",
                use_allowed = "unknown",
                identifiability_documented = "yes",
                data_dictionary = "yes",
                population_fits_question = "unknown",
                version_and_date_recorded = "yes",
                citation_requirement_known = "unknown")

my_source <- assess_source("My chosen source (placeholder answers)", my_answers)
cat("\nDecision: ", my_source$decision, "\n", sep = "")
print(my_source$detail %>% filter(status %in% c("blocker", "check first")) %>%
        select(question, answer, status))

assessments <- bind_rows(
  assessments,
  tibble(source = my_source$source,
         decision = my_source$decision,
         n_blockers = sum(my_source$detail$status == "blocker"),
         n_to_check = sum(my_source$detail$status == "check first"),
         date_checked = as.character(Sys.Date()))
)
write.csv(assessments, "output/L16_source_assessments.csv", row.names = FALSE)
stopifnot(nrow(assessments) == 5, my_source$decision == "Check the open points before use")
