# Adversarial review report (template)

Copy this file for each review round, for example `reviews/review_2026-11-08_round1.md`.
Part 1 is written by the reviewer (assistant B). Part 2 is written by the author (assistant A and/or the
human) in a separate step, after reading Part 1. The human makes the final decision on every finding.

## Part 1: Reviewer report

**Reviewer (tool and model, as shown by the tool):** [ ]
**Date:** [ ]  **Round:** [1, 2, ...]
**Version reviewed (commit or file hashes):** [ ]
**Session:** clean session, no access to the author's reasoning: [yes / no]
**Mode:** read-only: [yes / no]

### What I could not verify
- [ ]

### Findings

| ID | Severity | File / section | Problem (one sentence) |
|---|---|---|---|
| R-01 | High / Medium / Low | [ ] | [ ] |

#### R-01 [title]
- **Severity:** [High / Medium / Low]
- **File / section:** [ ]
- **Problem:** [ ]
- **Evidence (command and output, or "not verified"):**
  ```
  [ ]
  ```
- **Failing test or minimal reproduction:**
  ```r
  [ ]
  ```
- **Proposed fix:** [ ]
- **Confidence:** [high / medium / low] because [ ]

### Areas checked with no finding
- [ ]

### Summary counts
High: [ ]  Medium: [ ]  Low: [ ]

---

## Part 2: Assessment and review log

**Assessed by:** [author assistant and/or human]  **Date:** [ ]

For each finding: reproduce it first (run the failing test). Then decide. A reviewer's claim is a
hypothesis; the evidence is the test and, where the data are simulated, the known truth.

| ID | Reproduced? (yes / no / partly) | Decision (accept / reject / defer) | Reason | Action and test added | Commit | Status (open / fixed / rejected / deferred) |
|---|---|---|---|---|---|---|
| R-01 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

### Re-run after the fixes
- Test command and result (numbers of passed and failed tests): [ ]
- Known-truth or simulation checks re-run: [ ]
- Open High findings: [number]

### Decision of the human
- [Continue to another round / stop]. Reason: [ ]
- Signed off by: [name], date: [ ]

### Log of rounds

| Round | Reviewer | Date | High | Medium | Low | Open High after assessment |
|---|---|---|---|---|---|---|
| 1 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

Exit rule: stop when there are no open High findings and the human accepts the remaining Medium and Low
findings as fixed, deferred (with a reason) or rejected (with a reason). Two assistants agreeing is not
proof. The evidence is the test and the known truth.
