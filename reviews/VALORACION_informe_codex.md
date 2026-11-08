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

---

# Round 2 (fresh Codex session) - 2026-11-08

Report assessed: `reviews/REVISION_CODEX_repo_20261108_ronda2.md`. Codex was told not to read the round 1 report or this assessment. **No High finding.** It confirmed independently that the PheWAS fix works (strata with few events are labelled, no infinite odds ratios), that L13 does not reuse the test set, and that the package check gives 0/0/0.

| # | Codex severity | Finding | Decision | Decides |
|---|---|---|---|---|
| 6 | Medium | `renv.lock` exists but neither the README nor CI restores it | **Accept in part**: label and document; CI unchanged | David (policy) |
| 7 | Low | Generators fail or return invalid data at tiny sizes | **Accept** | Claude |
| 8 | Low | Anchor `ref`/`alt` hide that some rsIDs are multi-allelic | **Accept** (note, no rename) | Claude |

## 6. renv lockfile not used - accepted in part

True: the README and CI use `install_packages.R` (latest CRAN versions) while `renv.lock` was written on macOS with R 4.6.1. Two reproducibility paths with one undocumented is confusing. Applied: `install_packages.R` and the README now say that the default path installs the latest versions and that `renv::restore()` reproduces the verified versions. Not applied: restoring the lockfile in CI. The lockfile was created on macOS arm64; on Linux, `renv::restore()` would compile sf and its dependencies from source, which is slow and may fail, and a CI that tests against current packages also warns us early when a new CRAN release breaks a lesson. Whether the course should pin versions for learners is a policy decision for David.

## 7. Generator limits - accepted

Reproduced all three: `simulate_consumer_file(n_snps = 5)` (invalid 'size'), `simulate_population(n = 10, n_snps = 7)` (cannot sample 8 causal SNPs), `simulate_areas(1, 1)` (NaN values and a warning). Each now stops with a short message; regression test added (`generators reject sizes that cannot work`), including the smallest valid call of each.

## 8. Multi-allelic anchors - accepted

Checked: dbSNP lists more than two alleles for rs1801133, rs4988235, rs12913832 and rs1805007, as Codex says. The chosen pair is compatible with a real alternative. Added a comment in `anchor_variants()`. Not renamed to `simulated_ref`/`simulated_alt`: that would change the lessons (L09, L10) and the content that mention `ref` and `alt`.

## Status after round 2

70/70 scripts pass, 118 test expectations pass (1 skipped: Quarto render, CLI not installed). No open High finding. Open for David: item 2 (quasi-Poisson comparison in L29/L30), item 6 (pin versions or not), and installing Quarto to test the two `.qmd` templates.

---

# Adversarial review of the validation work (round 3) - 2026-11-08

Report assessed: `reviews/REVISION_ADVERSARIAL_codex_20261108.md`. Codex was asked to challenge the approach and to treat the earlier reports as claims to test. Evidence below comes from mutations and simulations run in a temporary copy of the repository. No fix has been applied yet; they wait for David's approval.

| # | Codex severity | Finding | Reproduced | Decision | Decides |
|---|---|---|---|---|---|
| A1 | High | No test protects the multiple-testing correction of L21 | **Yes**: replacing `p.adjust` by raw p-values in L21 made no test fail | **Accept** | Claude (David approves) |
| A2 | High | The 3-event rule is arbitrary and changes the Bonferroni family | **Partly** | **Accept the documentation part; reject "keep 40 tests"** | David for the lesson wording |
| A3 | High | L25 hides an invalid location (grid at the EPSG:27700 false origin) behind a 100 m tolerance | **Yes** (72.8 m) | **Accept in principle, defer** | David (visible outputs and content change) |
| M1 | Medium | `ensure_sim_data(dir, seed)` ignores both arguments | **Yes** by reading the code | **Accept, severity Low** | Claude |
| M2 | Medium | Quasi-Poisson test too loose; residual spatial autocorrelation not mentioned | **Yes**: generator coefficient 0.25 changed to 0.20, estimate became 0.201, test still passed | **Accept** | Claude; David for any course sentence |
| M3 | Medium | Bonferroni calibration test allows 15 percent | **Yes** by reading the test | **Accept** | Claude |
| M4 | Medium | CI only tests Linux, R release, latest packages; no artefacts | **Yes** | **Accept the artefact upload and a README wording fix; defer the matrix** | David (policy) |
| M5 | Medium | Coverage, planted truths and meta-analysis validated in favourable cases | **Yes** | **Defer** (acknowledge as a limit) | David |
| B1 | Low | Most lessons have no direct unit test | **Yes** | **Accept as wording** | Claude |
| B2 | Low | Mutation evidence extrapolated to "interval coverage" | **Yes** | **Accept as wording** | Claude |

## A1 - accepted

The new tests re-implement the PheWAS loop and call `p.adjust` themselves; none calls `add_corrections()`. The mutation removing both `p.adjust` calls from L21 left `test-statistics.R` and `test-codex-regressions.R` green. I over-claimed when `CHECKLOG.md` said the tests protect the PheWAS correction. Fix: load `run_phewas()` and `add_corrections()` from the lesson, run them on a simulated site and check that `p_bonferroni` and `p_bh` equal `p.adjust` of the tested p-values and exceed the raw ones; plus a hand-made table with `NA`.

## A2 - partly accepted

The cut-off of 3 is a convention, and Codex is right that it is neither derived nor referenced. But the objection that it inflates error by shrinking the Bonferroni denominator is not supported. Simulation (null PheWAS, 40 phenotypes with prevalences from 0.5 to 30 percent, n = 1,000, 250 studies per setting, Bonferroni over the tests actually run): family-wise error 0.044 with no rule, 0.052 with 1, **0.048 with 3**, 0.052 with 5 and 0.076 with 10 (standard error about 0.014). The rule depends on the counts of the outcome and exposure, not on the association, so it does not select on the effect. Rejected: fixing the family at 40 hypotheses (it would leave Bonferroni needlessly conservative for tests that were never run). Accepted: say in the lesson that 3 is a convention, show the excluded phenotypes (the `status` column already does) and keep this simulation as evidence (proposed: `tests/validation/phewas_min_events_fwer.R`, not run by default). Penalised or exact methods for sparse strata can be mentioned as the next step; that is a course content decision.

## A3 - accepted in principle, deferred

True: the simulated grid sits at (0, 0) to (14,000, 14,000) in EPSG:27700, near the false origin and far from Great Britain, so the transformation is approximate and my 100 m tolerance hides it. A proper fix is to place the grid in a real area (for example around E/N 530000/180000) while computing the smooth fields from local coordinates, so the simulated values stay identical. It changes the coordinates printed by L25 and L26 and the longitude/latitude shown in the course (L25 prints a bounding box in degrees), so the content must be checked first. Decision for David: (a) move the grid and update any figures that quote coordinates; (b) keep the grid and state in L25 that it is a fictional location where conversions are approximate; (c) leave it.

## M1 - accepted, severity Low

`dir` and `seed` of `ensure_sim_data()` are not honoured (the generator always writes `data-sim/out` with seed 2026). This was already so in the original code. Fix: remove the unused `seed` argument and stop if `dir` is not the default, with a clear message. No lesson passes either argument.

## M2 - accepted

Reproduced. The test needs absolute bounds based on the Monte Carlo error: over 60 area sets the standard deviation of the estimates is about 0.014 (PM2.5) and 0.026 (deprivation), so the standard error of the mean is below 0.004; bounds of 0.015 around the planted values would catch the 0.25 to 0.20 change. Also true and my omission: the Moran's I of the quasi-Poisson residuals is 0.068 (p = 0.027). The count model is a comparison, not a spatial model of counts. Fix: a comment in L29 stating this. A sentence in the L29 notes is David's decision.

## M3 - accepted

60 replications and a limit of 0.15 are too loose for a claim of about 0.05. Fix: test the implementation deterministically (A1) and make the stochastic check a binomial bound.

## M4 - accepted in part

Verified: the workflow tests only Linux, the current R release and latest packages; the README says "R 4.3 or later", which nobody tested. Accepted now: upload the two rendered HTML files as GitHub artefacts (this also serves David's pending visual check without installing Quarto) and change the README wording to say what was tested. Deferred to David: an R 4.3 / macOS matrix and a job that runs `renv::restore()`; this is the version-pinning policy he already decided.

## M5, B1, B2

M5 is deferred and recorded as a limit: the checks show that the estimators work in favourable conditions, not that the 1,000-per-site lesson will always reproduce the narrative. B1 and B2 are wording: the lesson runner is a smoke test, only part of the lessons have direct tests, and the mutation evidence supports only the claim "the Wald interval of `tidy_or` is built with 1.96".

## What Codex got wrong or overstated

- A2 implies that the rule adapts to the outcome and so inflates error; the simulation above does not show it.
- It calls the lack of a visual review of the HTML a gap in validation. It is a gap, and it is already on the to-do list.
- Its list of unverified items (external validity, visuals, other platforms) is accurate and is not a defect of the work done.

## Status of round 3 (after David approved the accepted fixes)

Applied: A1, M1, M2 (tests and L29 comment), M3, M4 (artefact upload and README wording), B1, B2, and the A2 documentation (validation script and CHECKLOG). Open: A3 (David), the L29 course sentence (David, course content), the CI matrix (David, policy), M5 (limit, deferred).
