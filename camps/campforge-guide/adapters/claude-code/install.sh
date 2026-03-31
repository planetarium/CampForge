#!/bin/bash
# CampForge campforge-guide adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install all skills via skillpm
cd "$CAMP_DIR" && npx skillpm install

# 2. Identity -> CLAUDE.md
{
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  echo "---"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 3. Knowledge
if [ -d "$CAMP_DIR/knowledge" ]; then
  cp -r "$CAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

echo ":: CampForge campforge-guide installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" 2>/dev/null | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
