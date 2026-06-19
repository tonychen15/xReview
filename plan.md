# Plan: Add Codex (OpenAI) as Third Agent in xReview

## Context

xReview is a cross-LLM code review tool where one AI agent implements and another reviews. Currently supports Claude Code and Gemini CLI only. The user wants to add OpenAI's Codex CLI as a third developer/reviewer agent.

**Branch:** `feature/add-codex-agent` (off main)

**Research:** Studied aider, open-code-review, OpenCode, and continue.dev. The aider pattern (flag-per-role: `--model`, `--editor-model`) is the closest fit. xReview already has developer/reviewer roles, so we add `--reviewer <agent>` flag.

## Key Design Decisions

### 1. Dynamic agent detection (1-3 agents)

xReview dynamically detects which agents are installed by checking `command -v`:

```bash
detect_installed_agents() {
  local agents=()
  command -v claude &>/dev/null && agents+=(claude)
  command -v gemini &>/dev/null && agents+=(gemini)
  command -v codex  &>/dev/null && agents+=(codex)
  echo "${agents[@]}"
}
```

The system works with **1 to 3 agents**:
- **3 installed:** Full cross-LLM review (developer + random or specified reviewer)
- **2 installed:** Classic mode (developer + the other one, or specified)
- **1 installed:** Self-review mode (developer reviews its own work)

### 2. Reviewer selection logic

```
resolve_reviewer(developer, requested_reviewer):
  installed = detect_installed_agents()
  peers = installed - developer

  if requested_reviewer is specified:
    if requested_reviewer not in installed:
      ERROR: "<agent> is not installed"
      if peers is not empty:
        SUGGEST: "Available reviewers: <peers>"
      exit 1
    if requested_reviewer == developer:
      ERROR: "reviewer cannot be the developer"
      exit 1
    return requested_reviewer

  if peers is empty:
    WARN: "No other agents installed. Developer will self-review."
    return developer

  return random(peers)
```

### 3. `--reviewer` flag parsed from args

```
# Explicit reviewer
xreview bugfix claude --reviewer codex "fix the bug"

# Random reviewer (picks from installed peers)
xreview bugfix claude "fix the bug"

# Only one agent installed — self-review
xreview bugfix claude "fix the bug"
# → WARN: No other agents installed. claude will self-review.

# Reviewer not installed — helpful error
xreview bugfix claude --reviewer codex "fix the bug"
# → ERROR: codex is not installed. Available reviewers: gemini
```

Slash commands are unchanged. `$ARGUMENTS`/`{{args}}` passes `--reviewer X` through to xreview, which parses it.

## Files to Change

### 1. `bin/xreview` — Core orchestrator

**New: `detect_installed_agents()`**
- Checks `command -v` for claude, gemini, codex
- Returns array of installed agent names
- Called once at script start, result cached in `INSTALLED_AGENTS`

**Replace `peer_of()` with `resolve_reviewer()`**
- Accepts developer name + optional requested reviewer
- If `--reviewer` specified: validate it's installed and != developer; reject with helpful message if not
- If no reviewer: pick random from installed peers; if no peers, self-review with warning

**Add codex case to `trigger_agent()`**
```bash
codex)
  if ! command -v codex &>/dev/null; then
    echo "ERROR: codex CLI not found in PATH" >&2
    exit 1
  fi
  cmd=(codex exec "$prompt" -C "$(pwd)" -s suggest)
  ;;
```
- Developer mode: `-s suggest` (can edit files)
- Reviewer mode: `-s read-only` (review only)

**Update `cmd_task()` arg parsing**
- Parse `--reviewer <name>` from positional args
- Pass to `resolve_reviewer`

**Update `usage()`**
- Show `--reviewer` flag and agent detection info

### 2. `codex/commands/` — Codex slash commands (new directory)

Codex uses SKILL.md format in `~/.agents/skills/` directories:

```
codex/commands/
├── xreview-bugfix/
│   ├── SKILL.md
│   └── agents/
│       └── openai.yaml
├── xreview-feature/
│   ├── SKILL.md
│   └── agents/
│       └── openai.yaml
└── xreview-refactor/
    ├── SKILL.md
    └── agents/
        └── openai.yaml
```

Each SKILL.md has YAML frontmatter + instructions to run `xreview <type> codex '{{args}}'`.

Each `agents/openai.yaml` has display metadata for Codex's skill discovery.

### 3. `templates/AGENTS.md` — Codex protocol file (new)

Same structure as templates/CLAUDE.md but named AGENTS.md (Codex convention). Installed as `$TARGET_DIR/AGENTS.md`.

### 4. `claude/commands/*.md` — No changes needed

`$ARGUMENTS` passes through `--reviewer X` to xreview.

### 5. `gemini/commands/*.toml` — No changes needed

`{{args}}` passes through `--reviewer X` to xreview.

### 6. `install.sh` — Add Codex support

- Copy codex skill directories to `$TARGET_DIR/.agents/skills/`
- Create/merge AGENTS.md via existing `install_context_file()`
- Add `.agents/` and `/AGENTS.md` to .gitignore entry loop
- Add codex CLI to verification section

### 7. `.gitignore` �� Add Codex patterns

```
.agents/
/AGENTS.md
```

### 8. `.github/workflows/ci.yml` — Add Codex file validation

```yaml
test -f codex/commands/xreview-bugfix/SKILL.md
test -f codex/commands/xreview-feature/SKILL.md
test -f codex/commands/xreview-refactor/SKILL.md
test -f templates/AGENTS.md
```

### 9. `README.md` — Update documentation

- Add Codex to agent list, prerequisites (`npm install -g @openai/codex`), usage examples
- Document `--reviewer` flag
- Document dynamic agent detection and self-review mode
- Update file layout diagram

### 10. `.github/pull_request_template.md` — Add Codex to checklist

## NOT in scope

- **Multi-reviewer** (both Gemini AND Codex review same change) — deferred
- **Codex config.toml generation** — user manages their own Codex config
- **LOCK file eval safety** — pre-existing issue, separate PR
- **Codex interactive mode** — only non-interactive `codex exec` supported

## What already exists (reuse, don't rebuild)

- `bin/xreview` LOCK file — already agent-agnostic (stores name strings)
- `trigger_agent()` — case/esac pattern, just add a case
- `install_context_file()` in install.sh — reuse for AGENTS.md merge
- `cmd_review()`, `cmd_commit()`, `cmd_rework()` — read from LOCK, no changes needed
- `.gitignore` entry loop in install.sh — just add to the list

## Verification

1. `shellcheck bin/xreview` — must pass clean
2. Test install.sh creates `.agents/skills/` and AGENTS.md
3. `xreview bugfix claude --reviewer codex "test"` — LOCK shows reviewer=codex
4. `xreview bugfix claude "test"` — randomly picks from installed peers
5. `xreview bugfix claude --reviewer nonexistent "test"` — errors with helpful message
6. `xreview bugfix claude --reviewer claude "test"` — errors (can't self-review)
7. With only claude installed: `xreview bugfix claude "test"` — self-review with warning
8. `xreview review` — triggers correct agent from LOCK
9. Codex SKILL.md files have valid YAML frontmatter
10. Backwards compatible: 2-agent system works without `--reviewer` flag

## Failure Modes

| Scenario | Behavior | User sees |
|----------|----------|-----------|
| `--reviewer codex` but codex not installed | Reject + show available reviewers | Clear error + suggestion |
| `--reviewer claude` when developer is claude | Reject | "reviewer cannot be the developer" |
| `--reviewer unknown` | Reject | "unknown is not a known agent" |
| No `--reviewer`, only 1 agent installed | Self-review with warning | Warning message, session proceeds |
| No `--reviewer`, 2+ agents installed | Random pick from peers | Session starts normally |
| codex exec hangs/times out | `wait` blocks | User can ctrl-c |
| AGENTS.md missing in project | Codex has no protocol | install.sh creates it |
