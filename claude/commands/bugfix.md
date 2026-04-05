# /bugfix — Fix a bug with xReview

IMPORTANT: You MUST run this shell command FIRST before doing anything else:

```bash
xreview bugfix claude "$ARGUMENTS"
```

Read the script's output carefully. It tells you the session number and what to append to .review/REVIEW.md.

Then follow these steps:
1. Append the session header and "Implementing" line to .review/REVIEW.md (use the exact format from the script output)
2. Investigate the bug described in the objective
3. If you find a bug: fix it, then run `xreview review`
4. If no bug exists: run `xreview nobug` to close the session
