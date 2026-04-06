#!/usr/bin/env bash
# xReview installer
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR=""

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
echo ""

# ── Function: Install Context File ──
install_context_file() {
    local target_dir="$1"
    local filename="$2"
    local template="$REPO_DIR/templates/$filename"
    local target="$target_dir/$filename"

    if [[ -f "$target" ]]; then
        if ! grep -q "xReview Protocol" "$target"; then
            echo "" >> "$target"
            cat "$template" >> "$target"
            echo "   ✅ Merged $filename section into $target"
        else
            echo "   ℹ️  $filename already has xReview section — skipped merge"
        fi
    else
        cp "$template" "$target"
        echo "   ✅ Created $target"
    fi
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

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Installation complete!                          ║"
echo "╚══════════════════════════════════════════════════╝"
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
