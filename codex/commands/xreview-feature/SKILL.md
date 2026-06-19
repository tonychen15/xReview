---
name: feature
description: |
  Implement a feature with xReview peer review. Codex is the developer,
  a peer LLM agent reviews your work.
  Use when: /feature, implement a feature with review
---

Run this command first:

```bash
xreview codex feature "$ARGUMENTS"
```

Read the script's output carefully. It tells you the session number and what to append to .review/REVIEW.md.

Then follow these steps:
1. Append the session header and "Implementing" line to .review/REVIEW.md (use the exact format from the script output)
2. Implement the feature described in the objective
3. When done, run `xreview review` to trigger the reviewer
