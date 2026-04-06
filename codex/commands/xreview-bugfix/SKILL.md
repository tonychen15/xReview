---
name: bugfix
description: |
  Fix a bug with xReview peer review. Codex is the developer,
  a peer LLM agent reviews your work.
  Use when: /bugfix, fix a bug with review
---

Run this command first:

```bash
xreview codex bugfix "$ARGUMENTS"
```

Read the script's output carefully. It tells you the session number and what to append to .review/REVIEW.md.

Then follow these steps:
1. Append the session header and "Implementing" line to .review/REVIEW.md (use the exact format from the script output)
2. Investigate the bug described in the objective
3. If you find a bug: fix it, then run `xreview review`
4. If no bug exists: run `xreview nobug` to close the session
