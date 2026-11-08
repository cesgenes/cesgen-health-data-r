# AI-assisted workflow for R health-analysis projects (lesson 40)

Educational material; it does not replace a health professional. All data are simulated.

This folder holds the templates used in lesson 40. They support one workflow: an assistant writes and
tests the code, a second and independent assistant tries to break it, and a human decides.

## Files

| File | Purpose |
|---|---|
| `AGENTS.md` | Project rules for tools that read a file called `AGENTS.md` (for example Codex CLI) |
| `CLAUDE.md` | The same rules for tools that read `CLAUDE.md` (Claude Code). Keep the two identical |
| `adversarial_review_prompt.md` | The prompt you give to the reviewer assistant |
| `review_report_template.md` | The report the reviewer writes (Part 1) and the assessment and log you write (Part 2) |

Tools change quickly. Before relying on any file name, command or feature, check the current
documentation of the tool you use.

## The workflow

1. **Privacy first (lesson 7).** Use simulated data and synthetic fixtures only. Give assistants code,
   schemas and aggregate summaries, never real patient data, a real person's genome, credentials or
   identifiable tables. Check what your tool sends to its provider and what your organisation's policy allows.
2. **Specify.** Write the task and the acceptance criteria before any code (what must be true when it is done,
   including cases that must fail).
3. **Build in small steps (assistant A).** Ask for a plan, work under git in a branch, run the code, read the
   errors, and let the assistant debug with a minimal reproducible example. Commit each working step.
4. **Test.** Unit tests (`testthat`), a known-truth simulation (planted effects must be recovered), fixed seeds,
   and `devtools::check()` for packages.
5. **Review (assistant B).** Open a clean session of a different model or tool. Give it `adversarial_review_prompt.md`
   and the repository, read-only, without A's reasoning. Save its report with `review_report_template.md`.
6. **Assess.** For every finding, reproduce it, then accept, reject (with a reason) or defer. A or the human fixes
   the accepted ones and adds a test that fails before the fix and passes after it. Re-run all tests.
7. **Repeat** with a new review round until there are no open High findings. The human decides when to stop.
8. **Keep the log** (Part 2 of the report) with the repository, and document the AI assistance in your methods or
   reproducibility section according to the rules of your journal or institution.

## Two rules to remember

- Agreement between two assistants is not proof. The evidence is the failing test, the passing test and the
  known truth.
- You are accountable for the analysis. Anything that informs a clinical decision needs human review.
