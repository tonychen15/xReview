# xReview

xReview development workflow where **Claude Code** and **Gemini CLI** take turns implementing and reviewing each other's code changes.

## Philosophy

One agent builds. The other reviews. A shared markdown log tracks everything. A file-based lock ensures only one agent writes code at a time.

- **Agents are responsible** — they log their own state transitions to REVIEW.md and decide what to do next
- **Script is tooling** — it writes/reads state (LOCK file), triggers agents, and exits
- **No diffs in REVIEW.md** — reviewers run `git diff` themselves
- **Max 5 iterations** — enforced to prevent infinite loops

## How It Works

```
User calls /bugfix from Claude Code (or Gemini CLI)
  → Claude becomes DEVELOPER, Gemini becomes REVIEWER

┌─────────────────────────────────────────────────────┐
│  IMPLEMENTING                                       │
│  Developer writes code, logs to REVIEW.md           │
│  Then calls: xreview review                         │
├─────────────────────────────────────────────────────┤
│  REVIEWING                                          │
│  Reviewer reads REVIEW.md + git diff                │
│  Logs verdict, then calls:                          │
│    commit  → COMMITTING (approved)                  │
│    rework  → REWORKING (needs changes)              │
├─────────────────────────────────────────────────────┤
│  COMMITTING                                         │
│  Developer commits, appends session-complete line   │
│  Session done.                                      │
├─────────────────────────────────────────────────────┤
│  REWORKING                                          │
│  Developer fixes issues, logs to REVIEW.md          │
│  Then calls: xreview review                         │
│  (back to REVIEWING — max 5 iterations)             │
└─────────────────────────────────────────────────────┘

Works in reverse too — Gemini implements, Claude reviews.
```

## Install

```bash
git clone https://github.com/tonychen15/xreview.git
cd xreview
./install.sh
```

Or install to a specific project:

```bash
./install.sh --project /path/to/your/project
```

The installer puts `xreview` in `~/.local/bin/`, installs Claude Code skills/commands to `~/.claude/`, and optionally copies `CLAUDE.md` + `GEMINI.md` into your project.

### Prerequisites

You need to run these CLIs installed:

- **Claude Code**: https://docs.anthropic.com/en/docs/claude-code
- **Gemini CLI**: `npm install -g @google/gemini-cli`

## Usage

From **Claude Code**:
```
/bugfix "fix the phone extension bug"
/feature "add dark mode support"
/refactor "extract shared workday package"
```

From **Gemini CLI**:
```
/bugfix "fix the phone extension bug"
/feature "add dark mode support"
/refactor "extract shared workday package"
```

From bash
```
xreview <task> <agent> <description...>
           │      │       └─ What to do (free text)
           │      └─ Who implements: claude or gemini
           └─ Task type: feature, bugfix, or refactor
```
The called agent becomes the developer; the peer becomes the reviewer.

## Commands

| Command | Description |
|---------|-------------|
| `xreview bugfix <agent> "<desc>"` | Start a bugfix session |
| `xreview feature <agent> "<desc>"` | Start a feature session |
| `xreview refactor <agent> "<desc>"` | Start a refactor session |
| `xreview review` | Trigger reviewer (called by developer when done) |
| `xreview commit` | Trigger commit (called by reviewer on APPROVED) |
| `xreview rework` | Trigger rework (called by reviewer on NEEDS_CHANGES) |
| `xreview status` | Show current session state |
| `xreview unlock` | Emergency: clear lock file |


## REVIEW.md Format

Each agent appends its own state transitions. No diffs are embedded.

```markdown
## Session #1 — 2026-04-02 01:31 UTC
**Type:** bugfix | **Developer:** claude | **Reviewer:** gemini
**Objective:** Fix phone extension bug

### Iteration 1
- **Implementing** — claude — 2026-04-02 01:31 UTC
- **Reviewing** — gemini — 2026-04-02 01:35 UTC
  > **Verdict:** NEEDS_CHANGES
  > **Findings:** Phone selector still too broad
  > **Action Items:** 1. Remove input[id*="phone"] selector

### Iteration 2
- **Reworking** — claude — 2026-04-02 01:37 UTC
- **Reviewing** — gemini — 2026-04-02 01:40 UTC
  > **Verdict:** APPROVED

**Session #1 complete — 2026-04-02 01:41 UTC (Duration: 10m)**
```

## File Layout

```
~/.local/bin/xreview  ← Global script
```

```
xreview/
├── README.md              ← you are here
├── install.sh             ← installer script
├── CLAUDE.md              ← Claude's workflow instructions
├── GEMINI.md              ← Gemini's workflow instructions
├── .review/               ← Auto-created at runtime
│   ├── REVIEW.md          ← Shared review log
│   └── LOCK               ← Access control lock file
├── claude/
│   └── commands/
│       ├── bugfix.md      ← /bugfix for Claude Code
│       ├── feature.md     ← /feature for Claude Code
│       └── refactor.md    ← /refactor for Claude Code
└── gemini/
    └── commands/
        ├── bugfix.toml    ← /bugfix for Gemini CLI
        ├── feature.toml   ← /feature for Gemini CLI
        └── refactor.toml  ← /refactor for Gemini CLI

```