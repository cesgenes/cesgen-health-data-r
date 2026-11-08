# Assessment of the Codex report (round 1) - 2026-11-08

Report assessed: `reviews/REVISION_CODEX_repo_20261108.md` (Castilian Spanish). Method: every finding was reproduced or checked before a decision. Agreement between two assistants is not evidence; the evidence is the reproduction, the failing test or the known simulated truth. "Decides" is who has the final word.

| # | Codex severity | Finding | Decision | Decides |
|---|---|---|---|---|
| 1 | High | `run_phewas()` fits sparse or separated strata and hides warnings | **Accept** | Claude (code), David (wording of the lesson) |
| 2 | Medium | Spatial lessons fit count data with unweighted `lm`, SEM and SAR, no offset | **Defer** (partly rejected) | David |
| 3 | Medium | No CI | **Accept** | Claude; David reviews the workflow |
| 4 | Medium | `ensure_sim_data()` accepts stale data | **Accept** | Claude |
| 5 | Low | Duplicate `.gitignore` entry | **Accept** | Claude |
| T | Transversal | `R CMD check` of `riskkit` not confirmed independently | **Accept as documentation** | Claude |

## 1. PheWAS with sparse or separated strata - accepted

Reproduced. Running the reviewer's example (10 exposed, no events among them) returned `or = 6.03e-23`, `lower = 0`, `upper = Inf`, `p = 0.9997` with no warning. It also happens with the shipped data: with the original rule, 10 of 38 tested phenotypes in site A and 9 of 39 in site B had fewer than 3 events among the exposed (for example PH02, PH19, PH22, PH36), so the printed table contained degenerate odds ratios. They were not significant and the meta-analysis step already excluded them, so no conclusion in the lessons was wrong, but the per-site table was misleading. Severity: the reviewer says High; I would call it Medium for the shipped output but High for anyone reusing the function, and it is treated as High for the process (second review round).

Fix (`lessons/L21_phewas_run.R`): a phenotype is tested only if there are at least `min_exposed` exposed patients and at least `min_events` (default 3) in each cell of the 2x2 table; the model must converge with finite estimates; a `status` column says why a phenotype was not tested. Consequence for the numbers: site A now runs 28 tests (was 38), so the Bonferroni threshold is 0.00179 (was 0.0013). PH01 and PH03 pass Bonferroni in site A, PH05 does not (OR 0.87 in this sample), and the pooled analysis finds PH01 and PH03. The "try this" task (min_exposed 10 to 30) still works (28 to 27 tests). Regression tests: `test-codex-regressions.R` (the reviewer's example; a well-supported phenotype is still fitted; no degenerate odds ratio in either shipped site).

## 2. Count outcome analysed with lm/SEM/SAR - deferred

Partly true: the outcome is generated as Poisson with a population denominator (`R/simulate_areas.R`), and L29/L30 model `log((cases + 0.5) / population * 1000)` with unweighted `lm`, `errorsarlm` and `lagsarlm`. Checked by simulation over 200 seeds against the planted truth (PM2.5 0.04, deprivation 0.25 per unit): `lm` on the log rate gives 0.038 and 0.253 (SD 0.014 and 0.033); a quasi-Poisson GLM with offset gives 0.039 and 0.253 (SD 0.011 and 0.026). So the lesson's estimates are unbiased here and the Poisson model is only somewhat more precise. The criticism that the Wald intervals are not those of the generating process is valid in principle. Not changed because adding or replacing models changes lesson text, slides and the L29/L30 outputs that the course content describes. Options for David: (a) add one quasi-Poisson-with-offset line to L29 as a comparison; (b) keep the spatial models and add a visible limitation note; (c) leave as is. Recommendation: (a), small and keeps the lesson readable.

## 3. No CI - accepted

Verified: no `.github/` in the repository. Added `.github/workflows/check.yaml` (system libraries for sf, R release, Quarto, `install_packages.R`, data generation, `tests/run_all_lessons.R`, `test_dir`). It cannot be tested locally; it will be checked on GitHub after the next push. It deliberately uses `install_packages.R` instead of `renv::restore()` because `renv.lock` was written on macOS and exact versions may not exist for Linux binaries.

## 4. Stale simulated data - accepted

Already recorded as an open issue in `CHECKLOG.md` (it caused the L09 failure after the rs1805007 fix). Fix: `00_generate_all.R` writes a fingerprint of the generator files; `ensure_sim_data()` rebuilds the folder from scratch if the fingerprint is missing or different. Related: `00_generate_all.R` sourced `R/` into the global environment even when called from a function, which produced a masking warning in the package test; it now sources locally. Regression test: `ensure_sim_data rebuilds data made by older generator code`.

## 5. Duplicate `.gitignore` entry - accepted

Verified (`renv/library/` twice). Removed.

## T. `riskkit` check - accepted as documentation

The reviewer could not finish `devtools::check()` within its session limit and reported that `R CMD check` on the source directory failed on Author/Maintainer. I did not reproduce that failure; `R CMD build` followed by `R CMD check` on the tarball (the route `devtools::check()` takes) ends in `Status: OK`. The log is saved in `reviews/riskkit_check_log_20261108.txt`, and the test suite repeats the check in a temporary copy.

## Points in the report that I checked and agree with, or note

- Codex could only confirm two of the six anchor variants online; all six were checked here against the NCBI Variation API (`CHECKLOG.md` section 5). Codex missed the wrong rs1805007 position that was corrected before its review.
- Codex found no numeric mismatch between content and script output; I found none either (see `CHECKLOG.md` section 6 for the two notes).
- Not verifiable here, unchanged: Quarto rendering of the two `.qmd` templates (Quarto CLI not installed).

## Status

Accepted fixes 1, 3, 4, 5 and T are applied, with regression tests for 1 and 4. Because a High finding was fixed, a second review round with a fresh Codex session follows. Item 2 is waiting for David.
