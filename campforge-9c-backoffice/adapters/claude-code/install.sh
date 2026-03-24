#!/bin/bash
# CampForge 9c-backoffice adapter for Claude Code

BOOTCAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$BOOTCAMP_DIR" && skillpm install)
fi

# 2. Copy skills
mkdir -p "$TARGET_DIR/.claude/skills"
cp -r "$BOOTCAMP_DIR/skills/9c-backoffice" "$TARGET_DIR/.claude/skills/9c-backoffice"

# Copy gql-ops: skillpm (node_modules) → local fallback (packages/)
if [ -d "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
elif [ -d "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
else
  echo "  [warn] gql-ops not found. Install via: skillpm install @campforge/gql-ops"
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

echo ":: CampForge 9c-backoffice installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
