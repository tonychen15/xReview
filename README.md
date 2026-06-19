# xReview

xReview development workflow where peer agents — **Claude Code**, **Codex CLI**, and **Gemini CLI** — take turns implementing and reviewing each other's code changes.

### Reviewer selection

When you don't name a reviewer explicitly, xReview chooses one by a fixed fallback order — the developer is never picked as its own reviewer until nothing else is left:

1. **Codex CLI** — the default review party.
2. **Gemini CLI** — the fallback when Codex isn't available as the reviewer (including when Codex is the developer). Requires a working `GEMINI_API_KEY` set up **in advance** (see [Gemini API key setup](#gemini-api-key-setup)); the OAuth "Sign in with Google" login is not relied upon.
3. **Any other installed agent** that isn't the developer.
4. **The coding model itself** — last-resort self-review, only when no peer agent is available (a warning is printed).

You can always override this by naming a reviewer (e.g. `xreview claude bugfix gemini "…"`).

## Philosophy

One agent builds. The other reviews. A shared markdown log tracks everything. A file-based lock ensures only one agent writes code at a time.

- **Agents are responsible** — they log their own state transitions to REVIEW.md and decide what to do next
- **Script is tooling** — it writes/reads state (LOCK file), triggers agents, and exits
- **No diffs in REVIEW.md** — reviewers run `git diff` themselves
- **Max 5 iterations** — enforced to prevent infinite loops

## How It Works

```
User calls /bugfix from Claude Code (or Gemini/Codex CLI)
  → Claude becomes DEVELOPER, Codex becomes REVIEWER (default)
  → (override by naming any installed peer as the reviewer)

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

Recommend: install to a specific project:

```bash
cd /path/to/xReview
./install.sh --project /path/to/your/project
```

Or install from your project:

```bash
cd /path/to/your/project
/path/to/xReview/install.sh
```

let The installer puts `xreview` in `~/.local/bin/`, installs Claude Code /commands to `/.claude/`, and optionally copies `CLAUDE.md` + `GEMINI.md` into your project.

### Updating

Re-run `install.sh` the same way you first installed — it's the update path:

- the `xreview` binary, command files, and Codex skills are overwritten with the latest;
- the xReview block inside `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` is delimited by
  `<!-- xReview:start ... -->` / `<!-- xReview:end -->` markers and is **replaced in place**, so your own content outside the markers is preserved (pre-marker installs are migrated automatically);
- the installed version is recorded at `.review/.xreview-version`, and the installer reports `Fresh install` / `Updating vX → vY` / `Reinstalling` accordingly.

Check what you have installed with `xreview version`.

### Prerequisites

Install at least two of these CLIs (one builds, the other reviews):

- **Claude Code**: https://docs.anthropic.com/en/docs/claude-code
- **Codex CLI**: https://github.com/openai/codex — the default reviewer
- **Gemini CLI**: `npm install -g @google/gemini-cli` — the fallback reviewer (needs the API key below)

### Gemini API key setup

Gemini is used as a reviewer when Codex is unavailable or is the developer, and the free OAuth ("Sign in with Google") login is currently unreliable (`IneligibleTierError`). Set it up with a free **Google AI Studio API key** instead so the fallback is ready in advance:

1. Create a key at https://aistudio.google.com/apikey (free tier — no billing).
2. **Restrict the key**: on the API Keys page choose **Add restrictions → Restrict to Gemini API only**. As of June 19, 2026 Google rejects requests from *unrestricted* API keys, so this step is required.
3. Make the key available to the CLI. The most reliable place is `~/.gemini/.env`, which the Gemini CLI auto-loads for **any** shell (a plain `export` in `~/.bashrc` is skipped by non-interactive shells, so `xreview` wouldn't see it):

   ```bash
   install -d -m 700 ~/.gemini                    # ensure the dir exists (private)
   printf 'GEMINI_API_KEY=%s\n' "YOUR_KEY_HERE" > ~/.gemini/.env
   chmod 600 ~/.gemini/.env                        # it holds a secret
   ```

4. Point the CLI at the key instead of OAuth (one-time):

   ```bash
   gemini   # then choose "Use Gemini API key"
   # or set ~/.gemini/settings.json -> security.auth.selectedType = "gemini-api-key"
   ```

Verify with `gemini -p "say OK"`. Note the free tier is rate-limited and may occasionally return "model experiencing high demand" — which is why Codex stays the default reviewer.

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