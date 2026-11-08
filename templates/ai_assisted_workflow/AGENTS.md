# AGENTS.md (template for an R health-analysis project)

> Copy this file to the root of your project and edit the parts in [square brackets].
> Codex CLI reads a file called `AGENTS.md`; Claude Code reads a file called `CLAUDE.md`.
> Other tools may use other names: check the current documentation of the tool you use.
> Keep `AGENTS.md` and `CLAUDE.md` identical in content so that every assistant gets the same rules.

## Project

[One or two sentences: what question this project answers, in plain words.]
Educational material; it does not replace a health professional. A statistical result is
not a clinical conclusion.

## Data rules (non-negotiable)

- All data in this project are SIMULATED or synthetic. There are no real patients in this repository.
- Never read, open, print, summarise, copy or ask for real patient data, a real person's genome,
  credentials, tokens, keys, or any table that could identify a person.
- If a file looks like real data (names, record numbers, dates of birth, postcodes, a genuine
  genotype file), STOP, do not open it, and tell the user.
- Work from code, schemas (column names and types), simulated data and aggregate summaries.
  Do not print more than a few rows of simulated data at a time.
- Do not send files or data to any web service or external tool. Do not add telemetry or uploads.
- Data files are not committed: `data-sim/out/` and `output/` stay out of version control.

## Working rules

- Run everything from the repository root (the RStudio project folder). Use relative paths only.
- Ask before installing any software or package (including `install.packages()`, `renv::restore()`,
  `pip`, `brew`, system libraries). Say what and why, then wait.
- Never push to any remote. Do not run `git push`, change remotes, force-update, rewrite history
  or delete branches. Local commits on a working branch are fine when asked.
- Ask before deleting files, and before changing anything outside this repository.
- Make small changes. Explain the plan first, then edit, then run the tests.
- If R or a package is not available, say so. Never invent the output of code you could not run.

## Code style

- Code, identifiers, comments and file names in English. Use UK English in prose.
- `snake_case` names, `<-` for assignment, two-space indentation, lines of about 100 characters or fewer.
- Every function has a short comment (or roxygen block) saying what it takes and returns.
- Use only functions and arguments you have checked in the documentation (`?function_name`) or in
  the installed package. If unsure, say so instead of guessing.
- Set a seed when randomness matters, and say where.

## How to run the checks

```
Rscript -e 'testthat::test_dir("tests/testthat")'     # unit tests
Rscript tests/run_all_lessons.R                        # every lesson script, in a clean R process
Rscript -e 'devtools::test()'                          # if the project is an R package
Rscript -e 'devtools::check()'                         # if the project is an R package
```

Run the tests before and after every change. Report the exact result (counts of passed and failed
tests), not a summary like "all good".

## Statistical conduct

- Write down the question, the outcome and the analysis plan before looking at results.
- Split into training and test data BEFORE selecting variables, tuning or choosing a threshold.
- Report missing data: how many rows or values were dropped, and in which groups.
- Join tables by an explicit key (for example `patient_id`), never by row position.
- Correct for multiple testing when many hypotheses are tested, and say which correction was used.
- Do not repeat analyses until something becomes significant. Report every analysis you ran.
- Do not weaken, delete or rewrite a test to make it pass. If a test seems wrong, explain why and ask.
- Numbers that appear in a report must be produced by code in the repository, not typed by hand.

## Definition of done

A task is done only when ALL of these are true:

1. The code runs from a clean R session, from the repository root.
2. The tests pass, and there is at least one new test for the behaviour you added or fixed
   (including one for a case that should fail).
3. No data files, credentials or personal information were added or printed.
4. Assumptions, limitations and anything you could not verify are listed in your final message.
5. The change is small enough to review, with a short summary of what changed and why.
6. You have NOT pushed anything.
