# Independent review commission (Codex) · repository `cesgen-health-data-r` · 08/11/2026

**Read-only review.** Do not modify any file except the output report. Work inside the repository folder. You have not seen how this code was written: judge it only by what is in front of you and by running it.

## What to read
- `README.md`, `install_packages.R`, `data-sim/00_generate_all.R`, every file in `R/`.
- Every script in `lessons/` and `lessons/solutions/`, and everything in `templates/` (report template, final project, `mini_health_package/`, `ai_assisted_workflow/`).
- `tests/` and `CHECKLOG.md` (the log of the previous run/fix pass).
- The course content that these scripts accompany (read-only), in `../../content_en.py` and its module files `../../content_en_m*.py`: slides, notes, "try this" tasks and the `script_file` of each lesson.

## What to review
1. **Correctness of the code.** Does every script run from the repository root on a clean machine, in order, with the declared packages? Wrong or non-existent functions or arguments, objects used before creation, silent `NA` handling, off-by-one errors, wrong joins, wrong time-series indexing, wrong or missing multiple-testing correction, data leakage and double-dipping in any "model" or "score" code, seeds that do not make results reproducible.
2. **Statistical validity.** Are the simulated truths really planted as documented (`R/simulate_*.R`) and recovered by the lesson scripts? Calibration under the null (p-values roughly uniform, false-positive rate near the nominal level), confidence-interval coverage, meta-analysis weights and zero-event handling, spatial models and Moran's I on the simulated areas, odds ratio to absolute risk conversions, polygenic-score evaluation by group.
3. **Claims versus output.** Do the numbers and statements in slides, notes and "try this" tasks match what the scripts actually print or plot? List every mismatch.
4. **Genetics and health facts in code and comments.** Anchor variants (rsID, chromosome, GRCh37 position, alleles), ICD codes, terminology, statements about databases (ClinVar, ACMG list, GWAS Catalog, OMOP) and regulation. Verify on the internet what you can; list what you could not verify.
5. **Privacy and safety.** Any path, file, example or prompt that could lead a learner to upload or expose real health or genetic data; data accidentally committed; secrets; scripts that write outside the project or to the user's home by default.
6. **Package-development material (lessons 36-40).** `templates/mini_health_package` must pass `devtools::document()`, `test()` and `check()`; the statements about PITS must agree with the PITS repository (read-only: `/Users/daviddelorenzo/Documents/ClaudeCowork/PROJECTS/GitHub/PITS`).
7. **Teaching quality.** Beginner readability, comments, naming, exercises that are doable in 10-20 minutes with the stated expected result, solutions that really solve the exercise, runtime of each script (flag anything over 60 s).
8. **Reproducibility and tooling.** renv lock, `.gitignore`, CI file, tests that would catch real regressions versus tests that only check that code runs.

## How to review
Run the code (R 4.3 or later). Try to break it: unusual seeds, smaller or larger `n`, missing packages, a clean clone. For each finding give a minimal reproduction or a failing test whenever you can. Classify each finding **High / Medium / Low** with file and line or section, the problem, the evidence, and the concrete proposed fix. Do not invent evidence. Say clearly what you could not run or verify.

## Output
Write the report in **Castilian Spanish (Spain)** to `reviews/REVISION_CODEX_repo_20261108.md` with: executive summary; findings ordered by severity; cross-cutting findings; list of proposed fixes; list of what you could not verify. When done, state the path of the report.
