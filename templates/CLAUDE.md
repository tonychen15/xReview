# xReview Protocol

## Quick Start
- `/bugfix "description"` — fix a bug with peer review
- `/feature "description"` — implement a feature with peer review
- `/refactor "description"` — refactor code with peer review

## Access Control

| State | Your Role | Permissions |
|-------|-----------|-------------|
| implementing | Developer | Full write access to all files |
| reviewing | Reviewer | ONLY edit `.review/REVIEW.md` |
| reworking | Developer | Full write access to all files |
| committing | Developer | Commit changes, finalize session |

Check status: `xreview status`
Emergency override: `xreview unlock`

## When You Are the Developer (implementing/reworking/committing)
- You have full write access. Build, fix, or refactor as needed.
- Append your state transition line to `.review/REVIEW.md` before starting work.
- When done implementing, call `xreview review` to trigger the reviewer.
- When committing (after approval), commit changes and append the session-complete line.

## When You Are the Reviewer (reviewing)
- Open `.review/REVIEW.md` and find the latest iteration.
- Run `git diff` to see the changes.
- Evaluate changes against the stated objective.
- Append your "Reviewing" line and fill in Verdict/Findings/Action Items.
- Call `xreview commit` if APPROVED.
- Call `xreview rework` if NEEDS_CHANGES.
- Do NOT edit any file other than `.review/REVIEW.md`.
