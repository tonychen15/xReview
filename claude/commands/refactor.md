# /refactor — Refactor code with xReview

IMPORTANT: You MUST run this shell command FIRST before doing anything else:

```bash
xreview refactor claude "$ARGUMENTS"
```

Read the script's output carefully. It tells you the session number and what to append to .review/REVIEW.md.

Then follow these steps:
1. Append the session header and "Implementing" line to .review/REVIEW.md (use the exact format from the script output)
2. Perform the refactoring described in the objective
3. When done, run `xreview review` to trigger the reviewer
