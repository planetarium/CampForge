#!/bin/bash
# CampForge adapter for Claude Code

BOOTCAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$BOOTCAMP_DIR" && skillpm install)
fi

# 2. Copy skills
mkdir -p "$TARGET_DIR/.claude/skills"
for skill_dir in "$BOOTCAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/$skill_name"
done

# Copy gql-ops: skillpm (node_modules) -> local fallback (packages/)
if [ -d "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
elif [ -d "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
fi

# 3. Identity -> CLAUDE.md
{
  cat "$BOOTCAMP_DIR/identity/SOUL.md"
  echo ""
  echo "---"
  echo ""
  cat "$BOOTCAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 4. Knowledge
if [ -d "$BOOTCAMP_DIR/knowledge" ]; then
  cp -r "$BOOTCAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

echo ":: CampForge installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
