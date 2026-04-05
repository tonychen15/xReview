#!/usr/bin/env bash
# xReview installer
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
INSTALL_MODE="global"

# Parse arguments
if [[ "${1:-}" == "--project" ]]; then
    PROJECT_DIR="${2:-}"
    if [[ -z "$PROJECT_DIR" ]]; then
        echo "Error: --project requires a path"
        exit 1
    fi
    # Convert to absolute path
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    INSTALL_MODE="project"
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║            xReview installer                     ║"
echo "╚══════════════════════════════════════════════════╝"

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

# ── Shared: Install bin/xreview to PATH ──
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

if [[ "$INSTALL_MODE" == "global" ]]; then
    # ── GLOBAL INSTALL ────────────────────────────────────────────────────────
    TARGET_DIR="$(pwd)"
    if [[ "$TARGET_DIR" == "$REPO_DIR" ]]; then
        echo "   ⚠️  You're running this from the xReview repo itself."
        echo "      Project files (CLAUDE.md, GEMINI.md, .review/) will be created here."
        echo "      To install into a different project, use: ./install.sh --project /path/to/project"
        echo ""
    fi
    echo "── Global install (commands → ~/.claude, ~/.gemini) ──"
    echo "── Project files → $TARGET_DIR ──"

    # Install commands globally
    CLAUDE_DIR="$HOME/.claude/commands"
    mkdir -p "$CLAUDE_DIR"
    cp "$REPO_DIR/claude/commands/"*.md "$CLAUDE_DIR/"
    echo "   ✅ Installed Claude commands → $CLAUDE_DIR/"

    GEMINI_DIR="$HOME/.gemini/commands"
    mkdir -p "$GEMINI_DIR"
    cp "$REPO_DIR/gemini/commands/"*.toml "$GEMINI_DIR/"
    echo "   ✅ Installed Gemini commands → $GEMINI_DIR/"

    # Project files in current directory
    mkdir -p "$TARGET_DIR/.review"
    if [[ ! -f "$TARGET_DIR/.review/REVIEW.md" ]]; then
        cp "$REPO_DIR/templates/REVIEW.md" "$TARGET_DIR/.review/REVIEW.md"
        echo "   ✅ Initialized $TARGET_DIR/.review/REVIEW.md"
    else
        echo "   ℹ️  $TARGET_DIR/.review/REVIEW.md already exists — skipped"
    fi

    install_context_file "$TARGET_DIR" "CLAUDE.md"
    install_context_file "$TARGET_DIR" "GEMINI.md"

else
    # ── PROJECT-LEVEL INSTALL ─────────────────────────────────────────────────
    echo "── Project install → $PROJECT_DIR ──"

    # Install commands into project
    mkdir -p "$PROJECT_DIR/.claude/commands"
    mkdir -p "$PROJECT_DIR/.gemini/commands"
    cp "$REPO_DIR/claude/commands/"*.md "$PROJECT_DIR/.claude/commands/"
    cp "$REPO_DIR/gemini/commands/"*.toml "$PROJECT_DIR/.gemini/commands/"
    echo "   ✅ Installed commands → $PROJECT_DIR/.claude/ and .gemini/"

    # Project files
    mkdir -p "$PROJECT_DIR/.review"
    if [[ ! -f "$PROJECT_DIR/.review/REVIEW.md" ]]; then
        cp "$REPO_DIR/templates/REVIEW.md" "$PROJECT_DIR/.review/REVIEW.md"
        echo "   ✅ Initialized $PROJECT_DIR/.review/REVIEW.md"
    else
        echo "   ℹ️  $PROJECT_DIR/.review/REVIEW.md already exists — skipped"
    fi

    install_context_file "$PROJECT_DIR" "CLAUDE.md"
    install_context_file "$PROJECT_DIR" "GEMINI.md"

    # Update .gitignore
    GITIGNORE="$PROJECT_DIR/.gitignore"
    touch "$GITIGNORE"
    for entry in ".claude/" ".gemini/" ".review/" "/CLAUDE.md" "/GEMINI.md"; do
        if ! grep -Fq "$entry" "$GITIGNORE"; then
            echo "$entry" >> "$GITIGNORE"
            echo "   ✅ Added $entry to .gitignore"
        fi
    done
fi

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
echo ""
