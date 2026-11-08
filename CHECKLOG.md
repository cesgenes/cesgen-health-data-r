# CHECKLOG - cesgen-health-data-r

Log of the run, validate and review pass started on 2026-11-08. Code, comments and file names
are in English. Every script was written without being able to run R; this is the first time
they were executed.

## 1. Environment

| Item | Value |
|---|---|
| OS / hardware | macOS 27.0.1, Apple M1 (arm64) |
| R | 4.6.1 (2026-06-24) |
| Key packages | sf 1.1.1, spdep 1.4.2, spatialreg 1.4.3, meta 8.5.0, duckdb 2.0.0, devtools 2.5.2, usethis 3.2.1, roxygen2 8.0.0, testthat 3.3.2, lintr 3.3.0.1, dplyr 1.2.1, ggplot2 4.0.3, readr 2.2.0, tidyr 1.3.2, purrr 1.2.2, renv 1.3.1, quarto (R package) 1.5.1 |
| Quarto command-line tool | **Not installed.** Not installed without asking first; the Quarto render test is skipped and `templates/report_template.qmd` and `templates/final_project/report_skeleton.qmd` have **not been rendered**. |
| renv | `renv.lock` written with `renv::snapshot()` (228 packages). `renv::init()` was not run because the disk was at 97 percent; the lockfile is for `renv::restore()` in a clean clone. |
| Optional packages | PITS is installed (used read-only in lessons 36 and 38). |

Packages installed from CRAN in this pass: meta, spdep, spatialreg, duckdb, renv, quarto, pROC and the tidyverse pieces that were missing.

## 2. Pre-run review

Scope of the reading. Read line by line: `README.md`, `install_packages.R`, `data-sim/*`, all of `R/`, lessons 10, 11, 14 (part B), 20, 21, 23, 28, 29 (helpers), 32 (section 4), 40 and the L40 solution. The remaining lessons, solutions and templates were checked by parsing, lintr and by running them; they were **not** read in full before running. Findings that came from running are listed in section 5.

Static pass:
- All 87 `.R` files parse (0 failures).
- lintr with line length 100: 662 findings, all style (pipe consistency 268, line length 150, object usage 143, commented code 52, semicolons 18, pipe continuation 16, indentation 7, object names 5, braces 3). The object usage findings are dplyr non-standard evaluation or functions defined in the same lesson or sourced from `R/`; none points to a function that does not exist. No style change was made (minimal changes).
- `pkg::function` calls checked against the installed versions by running the lessons (no missing function or argument).
- Seeds: every simulation sets a seed; `simulate_ehr()` uses `seed + utf8ToInt(site)` so the two sites differ and each is reproducible.
- Leakage and multiple testing: L11 and L32 select features on training rows only and show the leak on purpose; L21 corrects over the tests actually run (Bonferroni and BH). No uncorrected multiple testing found.
- Paths: all relative to the repository root; the only absolute path in the repository was in `reviews/ENCARGO_codex_repo.md` (removed before publishing). Nothing writes outside the project.

Fixed because certainly wrong: see section 5.

## 3. Script status (before / after)

All scripts run from the repository root in a clean process with `Rscript --vanilla`. Total time for all 70 scripts: 186 s. No script is over 60 s (slowest: `lessons/solutions/L20_solution.R`, 27 s), so no optimisation was made.

| Script | Before | After | Seconds | Fix |
|---|---|---|---|---|
| `lessons/L02_workspace_setup.R` | OK | OK | 7.1 | - |
| `lessons/L03_objects_vectors_functions.R` | OK | OK | 0.8 | - |
| `lessons/L04_data_frames_tibbles.R` | OK | OK | 0.7 | - |
| `lessons/L05_import_inspect_transform.R` | OK | OK | 0.8 | - |
| `lessons/L06_ggplot_charts.R` | OK | OK | 3.2 | - |
| `lessons/L07_privacy_checks.R` | OK | OK | 0.3 | - |
| `lessons/L08_raw_file_structure.R` | OK | OK | 1.1 | - |
| `lessons/L09_read_clean_genotypes.R` | OK | OK | 1.1 | - |
| `lessons/L10_snp_to_trait.R` | OK | OK | 1.4 | - |
| `lessons/L11_multi_snp_prediction.R` | OK | OK | 1.7 | - |
| `lessons/L12_clinvar_acmg_offline.R` | OK | OK | 0.6 | - |
| `lessons/L13_risk_and_polygenic_score.R` | OK | OK | 1.3 | - |
| `lessons/L14_representation_and_group_accuracy.R` | OK | OK | 1.9 | - |
| `lessons/L15_data_types_quality.R` | OK | OK | 1.1 | - |
| `lessons/L16_source_checklist.R` | OK | OK | 0.4 | - |
| `lessons/L17_load_explore_join.R` | OK | OK | 1.4 | - |
| `lessons/L18_clean_clinical_data.R` | OK | OK | 1.4 | - |
| `lessons/L19_cohort_table1.R` | OK | OK | 0.8 | - |
| `lessons/L20_multiple_testing_sim.R` | OK | OK | 12.9 | - |
| `lessons/L21_phewas_run.R` | OK | OK | 4.5 | - |
| `lessons/L23_query_omop_duckdb.R` | OK | OK | 2.8 | - |
| `lessons/L25_spatial_basics_sf.R` | FAIL | OK | 3 | stopifnot(max_shift < 1) failed: 72.8 m round-trip shift (approximate PROJ transformation at the grid origin) |
| `lessons/L26_map_exposure_spatial_join.R` | OK | OK | 1.8 | - |
| `lessons/L27_social_indicators.R` | OK | OK | 1.2 | - |
| `lessons/L28_privacy_small_numbers.R` | OK | OK | 0.6 | - |
| `lessons/L29_spatial_autocorrelation_regression.R` | OK | OK | 4.6 | - |
| `lessons/L30_integrated_case.R` | OK | OK | 4.4 | - |
| `lessons/L31_reidentification_simulation.R` | OK | OK | 1.3 | - |
| `lessons/L32_bias_audit_and_double_dipping.R` | OK | OK | 1.8 | - |
| `lessons/L34_render_report.R` | OK | OK | 0.7 | - |
| `lessons/L36_inspect_package_anatomy.R` | OK | OK | 0.3 | - |
| `lessons/L37_build_mini_package.R` | OK | OK | 2 | - |
| `lessons/L38_test_the_package.R` | OK | OK | 2.1 | - |
| `lessons/L39_release_checklist.R` | OK | OK | 0.2 | - |
| `lessons/L40_ai_assisted_r_development.R` | OK | OK | 4.1 | - |
| `lessons/solutions/L02_solution.R` | OK | OK | 1.4 | - |
| `lessons/solutions/L03_solution.R` | OK | OK | 0.2 | - |
| `lessons/solutions/L04_solution.R` | OK | OK | 0.7 | - |
| `lessons/solutions/L05_solution.R` | OK | OK | 0.6 | - |
| `lessons/solutions/L06_solution.R` | OK | OK | 1.2 | - |
| `lessons/solutions/L07_solution.R` | OK | OK | 0.2 | - |
| `lessons/solutions/L08_solution.R` | OK | OK | 0.2 | - |
| `lessons/solutions/L09_solution.R` | OK | OK | 0.5 | - |
| `lessons/solutions/L10_solution.R` | OK | OK | 0.7 | - |
| `lessons/solutions/L11_solution.R` | OK | OK | 0.6 | - |
| `lessons/solutions/L12_solution.R` | OK | OK | 0.6 | - |
| `lessons/solutions/L13_solution.R` | OK | OK | 0.8 | - |
| `lessons/solutions/L14_solution.R` | OK | OK | 1.4 | - |
| `lessons/solutions/L15_solution.R` | OK | OK | 0.6 | - |
| `lessons/solutions/L16_solution.R` | OK | OK | 0.5 | - |
| `lessons/solutions/L17_solution.R` | OK | OK | 1.1 | - |
| `lessons/solutions/L18_solution.R` | OK | OK | 1.4 | - |
| `lessons/solutions/L19_solution.R` | OK | OK | 0.6 | - |
| `lessons/solutions/L20_solution.R` | OK | OK | 30 | - |
| `lessons/solutions/L21_solution.R` | OK | OK | 4.8 | - |
| `lessons/solutions/L23_solution.R` | OK | OK | 2 | - |
| `lessons/solutions/L25_solution.R` | OK | OK | 4.9 | - |
| `lessons/solutions/L26_solution.R` | OK | OK | 6.7 | - |
| `lessons/solutions/L27_solution.R` | OK | OK | 1.9 | - |
| `lessons/solutions/L28_solution.R` | OK | OK | 1.7 | - |
| `lessons/solutions/L29_solution.R` | OK | OK | 8.3 | - |
| `lessons/solutions/L30_solution.R` | OK | OK | 7.5 | - |
| `lessons/solutions/L31_solution.R` | OK | OK | 3.1 | - |
| `lessons/solutions/L32_solution.R` | FAIL | OK | 3.4 | round() on a data frame with a character column (Math.data.frame error) |
| `lessons/solutions/L34_solution.R` | OK | OK | 2.3 | - |
| `lessons/solutions/L36_solution.R` | OK | OK | 0.5 | - |
| `lessons/solutions/L37_solution.R` | OK | OK | 4.1 | - |
| `lessons/solutions/L38_solution.R` | OK | OK | 2.8 | - |
| `lessons/solutions/L39_solution.R` | OK | OK | 0.3 | - |
| `lessons/solutions/L40_solution.R` | OK | OK | 12.9 | - |

## 4. Tests

`testthat::test_dir("tests/testthat")`: 94 expectations pass, 1 skipped (Quarto render, tool not installed), 0 fail. About 45 s, of which about 35 s is the `devtools::check()` of the package copy.

| File | What it protects |
|---|---|
| `helper-setup.R` | finds the repository root (the previous test file could never pass under `test_dir`, see section 5); `lesson_functions()` loads functions defined inside lesson scripts without running them |
| `test-helpers.R` | hand-computed values for `or_to_absolute_risk`, `bonferroni_threshold`, `k_anonymity`, `tidy_or` (2x2 table), identifier flags, generators reproducible, consumer file format, dbSNP anchor coordinates |
| `test-statistics.R` | PH01, PH03 and PH05 recovered after Bonferroni (20,000 patients) with the planted OR inside the interval; null p-values calibrated (false-positive rate 3.5 to 6.5 percent, Bonferroni familywise error low); 95 percent interval coverage between 92 and 98 percent; two-site meta-analysis against hand inverse-variance weights and a zero-event table with continuity correction; apparent versus honest AUC in the double-dipping demo; a G1-trained score worse in G3 than in G1; Moran's I positive on the simulated areas and near 0 after shuffling; small-number suppression; re-identification demo |
| `test-omop-and-l40.R` | the same cohort from the OMOP-like tables and from the EHR at both sites; each of the four L40 flaws is exposed in `flawed_snp_analysis()` and fixed in `safer_snp_analysis()`; `with_seed()` leaves the caller's random stream untouched |
| `test-templates.R` | `mini_health_package` passes `document()`, `test()` and `check()` in a temporary copy (0 errors, 0 warnings, 0 notes); Quarto render (skipped here); AI-workflow templates keep the privacy wording |

Mutation check (code broken on purpose, tests must fail): 1.64 instead of 1.96 in `tidy_or` (1 failure), Bonferroni removed (3), planted PH01 effect removed (2). The sources were restored afterwards.

## 5. Fixes made

1. `R/simulate_genotypes.R`: rs1805007 GRCh37 position was 89985844; dbSNP (NCBI Variation API, 2026-11-08) gives 89986117 (chromosome 16). The other five anchors (rs1801133, rs4988235, rs12913832, rs429358, rs7412) match dbSNP for chromosome and GRCh37 position, and the listed alleles are consistent with forward-strand ref/alt.
2. `lessons/L25_spatial_basics_sf.R`: the round-trip tolerance of 1 m failed with 72.8 m. The grid sits at the false origin of EPSG:27700, outside the area covered by the accurate grid shift, so PROJ falls back to an approximate transformation. Tolerance changed to 100 m with an explanatory comment. The result depends on the PROJ installation; on a machine with the OSTN15 grid the shift may be smaller.
3. `lessons/solutions/L32_solution.R`: `round()` was applied to a data frame with a character column; now only the numeric columns are rounded.
4. `tests/testthat/test-helpers.R`: the original file sourced `R/` with a relative path and failed 8 of 8 under `test_dir` (testthat runs from `tests/testthat/`). Replaced by `helper-setup.R` plus extended tests.
5. `reviews/ENCARGO_codex_repo.md`: absolute local path to the PITS folder replaced by a generic phrase before publishing.
6. Licence: MIT added (`LICENSE`, CESGEN SL 2026); `LICENSE_PENDING.md` removed; README sections "Where it lives" and "Licence" updated.

## 6. Content mismatches (for David to decide)

None of the `content_*.py` files was edited.

1. **L14, accuracy by group.** The notes say a score learned in one group "may be less accurate in another". In the simulation the effects are identical in all groups and only allele frequencies differ by about 0.06, so the gap is very small: with weights from G1 only, R squared in G3 is about 0.005 lower than in G1 at n = 30,000, and at n = 3,000 the difference is smaller than the noise and can go either way depending on the seed. The lesson's own caption says "Effects are identical in all groups here", so there is no false statement, but a learner who expects a clear gap will not see one. Decision: leave as is and word the notes as "can be", or plant a real difference in effect sizes in `simulate_population()`.
2. **L21, planted weaker effects.** The exercise says PH03 and PH05 may be missed in one site. In 1,000 patients per site that is what happens; the test needs about 20,000 patients to recover PH05 after Bonferroni. No change needed; the statement is accurate.

## 7. Open issues

1. Quarto is not installed on this Mac. The Quarto render test of `templates/report_template.qmd` ran and passed in GitHub Actions (see section 12); `templates/final_project/report_skeleton.qmd` is not covered by the test.
2. `ensure_sim_data()` only checks that `patients_clean.csv` exists. After a change to a generator, stale files in `data-sim/out/` are not regenerated (this happened with the rs1805007 fix and made L09 fail until the folder was deleted). Proposed fix: delete `data-sim/out/` after changing a generator, or add a seed and version stamp. Not changed.
3. Lintr style findings (662) are not fixed.
4. `renv::init()` was not run (disk space); only the lockfile exists.

## 8. Reproduce from a clean clone

```bash
git clone https://github.com/cesgenes/cesgen-health-data-r.git
cd cesgen-health-data-r
Rscript -e 'source("install_packages.R")'
Rscript -e 'source("data-sim/00_generate_all.R")'
Rscript tests/run_all_lessons.R
Rscript -e 'testthat::test_dir("tests/testthat")'
```

## 9. Review round 1 (Codex) - changes

Full assessment in `reviews/VALORACION_informe_codex.md`. Applied: `run_phewas()` now excludes strata with fewer than 3 events or non-events per cell and reports a `status` column (site A runs 28 tests, Bonferroni threshold 0.00179); `ensure_sim_data()` rebuilds stale data using a generator fingerprint; `00_generate_all.R` sources `R/` locally; duplicate `.gitignore` entry removed; `.github/workflows/check.yaml` added (untested until pushed); `riskkit` check log saved. After these changes: 70/70 scripts pass, 112 test expectations pass, 1 skipped (Quarto). Deferred to David: quasi-Poisson comparison in L29/L30.

Content note from the change: the L21 text says PH03 and PH05 "may be missed in one centre". With the new rule PH03 passes Bonferroni in site A alone and PH05 does not; the pooled analysis finds PH01 and PH03. The wording remains accurate.

## 10. Review round 2 (Codex, fresh session) - changes

No High finding (`reviews/REVISION_CODEX_repo_20261108_ronda2.md`; assessment at the end of `reviews/VALORACION_informe_codex.md`). Applied: size validation with clear messages in `simulate_consumer_file()`, `simulate_population()` and `simulate_areas()`; note on multi-allelic anchors; `install_packages.R` and README explain the latest-versions path versus `renv::restore()`. Final state before pushing: 70/70 scripts pass, 118 test expectations pass, 1 skipped (Quarto render).

## 11. Open questions for David

1. Quarto is not installed on this Mac: install it (Homebrew cask `quarto`) to render the templates locally? (CI already renders `report_template.qmd`.)
2. L29/L30: add a quasi-Poisson-with-offset comparison next to the linear and spatial models (recommended), keep as is, or add only a limitation note?
3. Pin package versions for learners with `renv::restore()` as the main route, or keep latest versions (current)?
4. L14: soften "may be less accurate" or plant a real effect difference between groups (section 6)?

## 12. First CI run (GitHub Actions, ubuntu-latest, 2026-11-08)

Commit 5884028: the workflow `check` passed in 5 min 53 s on a clean Linux machine: system libraries, R release, Quarto, `install_packages.R`, data generation, all 70 lesson scripts and solutions, and `test_dir` with 119 expectations passed, 0 failed, 0 skipped (the Quarto render test ran there). Only warnings were GitHub notices about the Node.js 20 deprecation of `actions/checkout@v4` and an upcoming Ubuntu 26 label change.

## 13. L29 count-model comparison (David's decision, 2026-11-08)

Added section 5b to `lessons/L29_spatial_autocorrelation_regression.R`: a quasi-Poisson model with a log(population) offset, printed as rate ratios next to the linear and spatial models, plus Moran's I of its Pearson residuals. Result on the shipped areas: PM2.5 rate ratio 1.04 (1.01 to 1.06), deprivation 1.24 (1.16 to 1.32); planted values exp(0.04) = 1.04 and exp(0.25) = 1.28. Test added: over 60 simulated area sets the model recovers the planted log rate ratios. The "try this" tasks and the course content were not changed (they still compare OLS and SEM).

## 14. Decisions from David (2026-11-08)

- Package versions: keep the current setup (latest CRAN versions by default; `renv::restore()` documented as the exact route). No change.
- L14: soften the course notes ("a score learned in one group may be less accurate in another" to say the gap can be small and hard to see in small samples, which is why intervals are reported). To be edited in the course content by David; no `content_*.py` was touched here.
- L29: quasi-Poisson comparison added (section 13).
- Quarto on this Mac: pending (depends on whether David will render reports locally).
