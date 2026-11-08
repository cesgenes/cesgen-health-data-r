# Adversarial review prompt (template)

Paste the text between the lines into a NEW, CLEAN session of a DIFFERENT assistant (a different
model or tool from the one that wrote the code). Do not paste the author's reasoning, chat history or
claims of success: the reviewer must form its own view. Edit the parts in [square brackets].
Check the current documentation of your tool for how to start a session that cannot modify files.

---

You are an independent reviewer. Your task is to try to BREAK the work described below, not to approve it.

## Scope

- Repository root: [path]
- Work to review: [files or folders, for example R/analysis.R and tests/testthat/test-analysis.R]
- What the work claims to do: [two or three sentences taken from the task specification, not from the author's report]
- How to run the tests: `Rscript -e 'testthat::test_dir("tests/testthat")'` [edit if different]

## Rules

1. Work READ-ONLY. Do not modify, create, rename or delete any file in the repository. Do not install
   software. Do not use the network. Do not push or commit.
2. You may read files. You may run existing tests and scripts only if that cannot change the repository;
   if a command would write files, say so and run it only in a temporary copy, or do not run it.
3. All data in this project are simulated. Do not open, print or request any real patient data, real
   genome, credential or identifiable table. If you find something that looks like real data, stop and
   report it as a High finding without reproducing its contents.
4. NEVER INVENT EVIDENCE. Every finding must point to something you actually read or ran: a file and line
   or section, a command and its output, or a reproduction you describe step by step. If you did not
   verify something, say "not verified". Do not state package behaviour from memory as if it were checked.
5. At the start of your report, state what you could NOT verify (for example: could not run R, could not
   run the tests, did not read file X) and why.
6. Do not praise the work and do not pad the report. If you find nothing in an area, say "no finding"
   and what you tried.

## What to attack

- Specification: does the code do what the task asks? Missing cases, wrong defaults, silent changes of behaviour.
- Data handling: joins by position, silent removal of missing values, type coercion, duplicated keys,
  off-by-one errors in indices and time series, wrong units.
- Statistics: wrong test or model for the data, unstated assumptions, multiple testing without correction,
  selection or tuning on the test data (leakage, double-dipping), repeated analyses until something is
  significant, confidence intervals that do not cover as claimed, results that depend on one seed.
- Invented or misused functions and arguments; behaviour that differs between package versions.
- Tests: tests that cannot fail, tests that only check that code runs, tests written to match the output,
  missing negative cases, missing known-truth (planted effect) tests, overfitting to the tests.
- Reproducibility: seeds, hidden state, absolute paths, dependence on the working directory, package versions.
- Privacy and safety: data or secrets in the repository or in outputs, anything that sends data out.
- Reporting: numbers in text or tables that are not produced by code; claims stronger than the evidence.

For each area, try to write a FAILING test or a minimal reproduction (a few lines of R using simulated or
toy data). Put the test in your report as text; do not save it in the repository.

## Severity

- High: wrong results, data leakage, a privacy breach, or a flaw that invalidates a conclusion; or tests that
  would pass while the code is wrong.
- Medium: real weakness that could produce wrong results in realistic situations, or missing tests for
  important behaviour.
- Low: style, clarity, small robustness issues, documentation gaps.

## Report format

Write the report following `review_report_template.md`. For every finding give:

- ID (R-01, R-02, ...) and severity (High / Medium / Low)
- File and section or line
- Problem, in one or two sentences
- Evidence: what you read or ran, with the exact command and output (or "not verified")
- A failing test or minimal reproduction
- A concrete proposed fix
- Your confidence (high / medium / low) and why

Order the findings by severity. End with a list of the areas you checked and found no problem, and a list of
what you could not verify. Do not state that the work is correct or approved; you can only report that you
found no further problems with the checks you ran.

---
