#!/bin/bash
# CampForge adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy camp skills
mkdir -p "$TARGET_DIR/.claude/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/$skill_name"
done

# 3. Identity -> CLAUDE.md
{
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  echo "---"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 4. Knowledge
if [ -d "$CAMP_DIR/knowledge" ]; then
  cp -r "$CAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

echo ":: CampForge campforge-guide installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
