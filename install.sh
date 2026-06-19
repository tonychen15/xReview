#!/usr/bin/env bash
# xReview installer
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR=""
XREVIEW_VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "unknown")"

# Parse arguments
if [[ "${1:-}" == "--project" ]]; then
    TARGET_DIR="${2:-}"
    if [[ -z "$TARGET_DIR" ]]; then
        echo "Error: --project requires a path"
        exit 1
    fi
    # Create if needed, then convert to absolute path
    mkdir -p "$TARGET_DIR"
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
else
    TARGET_DIR="$(pwd)"
fi

# ── Case 4: Running from the xReview repo without --project ──
if [[ "$TARGET_DIR" == "$REPO_DIR" || "$TARGET_DIR" == "$REPO_DIR"/* ]]; then
    echo "⚠️  You're running this from the xReview repo itself."
    echo ""
    echo "Usage:"
    echo "  Recommended — install to a specific project:"
    echo "    ./install.sh --project /path/to/your/project"
    echo ""
    echo "  Or run from your project directory:"
    echo "    cd /path/to/your/project"
    echo "    $REPO_DIR/install.sh"
    exit 1
fi

# ── Case 3: Running from $HOME ──
if [[ "$TARGET_DIR" == "$HOME" ]]; then
    echo "⚠️  Target directory is your home folder ($HOME)."
    echo "   This will create CLAUDE.md, GEMINI.md, AGENTS.md, and .review/ in $HOME."
    echo ""
    read -rp "   Continue? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║            xReview installer                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo "── Installing to: $TARGET_DIR ──"

# ── Detect a prior install (version stamp) to report fresh vs update ──
STAMP_FILE="$TARGET_DIR/.review/.xreview-version"
PREV_VERSION=""
[[ -f "$STAMP_FILE" ]] && PREV_VERSION="$(cat "$STAMP_FILE" 2>/dev/null || true)"
if [[ -z "$PREV_VERSION" ]]; then
    echo "── Fresh install: v${XREVIEW_VERSION} ──"
elif [[ "$PREV_VERSION" == "$XREVIEW_VERSION" ]]; then
    echo "── Reinstalling v${XREVIEW_VERSION} (already current) ──"
else
    echo "── Updating: v${PREV_VERSION} → v${XREVIEW_VERSION} ──"
fi
echo ""

# ── Function: Install Context File ──
# The xReview content is wrapped in <!-- xReview:start ... --> / <!-- xReview:end -->
# markers so re-running the installer can replace just that block in place, leaving
# any user-authored content outside the markers untouched. Pre-marker ("legacy")
# installs appended the raw template at EOF; we migrate those to the marker form.
install_context_file() {
    local target_dir="$1"
    local filename="$2"
    local template="$REPO_DIR/templates/$filename"
    local target="$target_dir/$filename"
    local start_marker="<!-- xReview:start (v${XREVIEW_VERSION}) — managed block, do not edit; re-run install.sh to update -->"
    local end_marker="<!-- xReview:end -->"

    local tmp_block tmp_out
    tmp_block="$(mktemp)"
    tmp_out="$(mktemp)"
    { printf '%s\n' "$start_marker"; cat "$template"; printf '%s\n' "$end_marker"; } > "$tmp_block"

    if [[ ! -f "$target" ]]; then
        cp "$tmp_block" "$target"
        echo "   ✅ Created $target (v${XREVIEW_VERSION})"
    elif grep -q "<!-- xReview:start" "$target"; then
        # Validate marker pairing while replacing, in a single pass. A start while
        # already inside a block (nested), a stray end with no open start, or an
        # unterminated start at EOF all make awk exit non-zero — so we abort before
        # overwriting and user content is never silently dropped. Multiple well-formed
        # blocks collapse into one (the new block is emitted only at the first start).
        if awk -v blockfile="$tmp_block" '
            BEGIN { while ((getline line < blockfile) > 0) block = block line ORS }
            /<!-- xReview:start/ { if (inside) exit 3; inside=1; starts++; if (starts==1) printf "%s", block; next }
            /<!-- xReview:end -->/ { if (!inside) exit 3; inside=0; next }
            !inside { print }
            END { if (inside) exit 3 }
        ' "$target" > "$tmp_out"; then
            mv "$tmp_out" "$target"
            echo "   ✅ Updated xReview block in $target (v${XREVIEW_VERSION})"
        else
            echo "   ❌ $target has malformed xReview markers (unbalanced, nested, or stray)."
            echo "      Refusing to edit (would risk losing content). Fix the markers"
            echo "      manually, then re-run."
            rm -f "$tmp_block" "$tmp_out"
            exit 1
        fi
    elif grep -q "^# xReview Protocol" "$target"; then
        # Legacy install: the raw template was appended at EOF (no markers). Only
        # auto-migrate when the text from the heading to EOF is still exactly the
        # template — otherwise the user edited the block or added content after it,
        # and truncating to EOF would silently lose that. Both sides are normalised
        # through awk so a trailing-newline difference doesn't cause a false mismatch.
        awk '/^# xReview Protocol/ { f=1 } f { print }' "$target" > "$tmp_out"
        if diff -q <(awk '{print}' "$tmp_out") <(awk '{print}' "$template") >/dev/null 2>&1; then
            awk '/^# xReview Protocol/ { exit } { print }' "$target" > "$tmp_out"
            cat "$tmp_block" >> "$tmp_out"
            mv "$tmp_out" "$target"
            echo "   ✅ Migrated legacy xReview block to markers in $target (v${XREVIEW_VERSION})"
        else
            echo "   ❌ $target has a legacy xReview block that was edited or has content after it."
            echo "      Refusing to migrate automatically (would risk losing content). Wrap the"
            echo "      xReview section in <!-- xReview:start --> / <!-- xReview:end --> markers"
            echo "      manually, then re-run."
            rm -f "$tmp_block" "$tmp_out"
            exit 1
        fi
    else
        # Existing file with no xReview content — append a fresh marked block.
        printf '\n' >> "$target"
        cat "$tmp_block" >> "$target"
        echo "   ✅ Merged xReview block into $target (v${XREVIEW_VERSION})"
    fi
    rm -f "$tmp_block" "$tmp_out"
}

# ── Install bin/xreview to PATH ──
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/bin/xreview" "$BIN_DIR/xreview"
chmod +x "$BIN_DIR/xreview"
echo "   ✅ Installed xreview → $BIN_DIR/"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "   ⚠️  $BIN_DIR is not in your PATH"
    echo "      Add this to your shell profile:"
    echo "        export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── Install commands ──
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.gemini/commands"
cp "$REPO_DIR/claude/commands/"*.md "$TARGET_DIR/.claude/commands/"
cp "$REPO_DIR/gemini/commands/"*.toml "$TARGET_DIR/.gemini/commands/"
echo "   ✅ Installed Claude + Gemini commands"

# Install Codex skills
for skill_dir in "$REPO_DIR/codex/commands/"*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$TARGET_DIR/.agents/skills/$skill_name/agents"
    cp "$skill_dir/SKILL.md" "$TARGET_DIR/.agents/skills/$skill_name/"
    cp "$skill_dir/agents/openai.yaml" "$TARGET_DIR/.agents/skills/$skill_name/agents/"
done
echo "   ✅ Installed Codex skills → .agents/skills/"

# ── Initialize .review/REVIEW.md ──
mkdir -p "$TARGET_DIR/.review"
if [[ ! -f "$TARGET_DIR/.review/REVIEW.md" ]]; then
    cp "$REPO_DIR/templates/REVIEW.md" "$TARGET_DIR/.review/REVIEW.md"
    echo "   ✅ Initialized .review/REVIEW.md"
else
    echo "   ℹ️  .review/REVIEW.md already exists — skipped"
fi

# ── Install CLAUDE.md, GEMINI.md, and AGENTS.md ──
install_context_file "$TARGET_DIR" "CLAUDE.md"
install_context_file "$TARGET_DIR" "GEMINI.md"
install_context_file "$TARGET_DIR" "AGENTS.md"

# ── Update .gitignore ──
GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"
for entry in ".claude/" ".gemini/" ".agents/" ".review/" "/CLAUDE.md" "/GEMINI.md" "/AGENTS.md"; do
    if ! grep -Fq "$entry" "$GITIGNORE"; then
        echo "$entry" >> "$GITIGNORE"
        echo "   ✅ Added $entry to .gitignore"
    fi
done

# ── Stamp the installed version last, so a failed/partial install isn't recorded
#    as current (lives under the gitignored .review/). ──
printf '%s\n' "$XREVIEW_VERSION" > "$STAMP_FILE"
echo "   ✅ Stamped version v${XREVIEW_VERSION} → .review/.xreview-version"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Installation complete!                          ║"
echo "╚══════════════════════════════════════════════════╝"
echo "  xReview v${XREVIEW_VERSION}"
echo ""
echo "  Commands available:"
echo "    /bugfix \"desc\""
echo "    /feature \"desc\""
echo "    /refactor \"desc\""
echo ""

# ── Verification ──
echo "── Verification ──"
if command -v claude &>/dev/null; then
    echo "  ✅ claude CLI: FOUND"
else
    echo "  ❌ claude CLI: NOT FOUND — https://docs.anthropic.com/en/docs/claude-code"
fi

if command -v gemini &>/dev/null; then
    echo "  ✅ gemini CLI: FOUND"
else
    echo "  ❌ gemini CLI: NOT FOUND — npm install -g @google/gemini-cli"
fi

if command -v codex &>/dev/null; then
    echo "  ✅ codex CLI: FOUND"
else
    echo "  ❌ codex CLI: NOT FOUND — npm install -g @openai/codex"
fi
echo ""
