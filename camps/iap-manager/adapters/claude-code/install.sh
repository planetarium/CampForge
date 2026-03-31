#!/bin/bash
# CampForge iap-manager adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"

# 1. Resolve skill dependencies via skillpm
npx skillpm install 2>/dev/null || true

# 2. Copy camp skills
mkdir -p "$TARGET_DIR/.claude/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/$skill_name"
done

# 3. Copy shared skill dependencies (skillpm node_modules → local packages/ fallback)
for pkg in gql-ops; do
  if [ -d "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" ]; then
    cp -r "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" "$TARGET_DIR/.claude/skills/$pkg"
  elif [ -d "$REPO_ROOT/packages/$pkg/skills/$pkg" ]; then
    cp -r "$REPO_ROOT/packages/$pkg/skills/$pkg" "$TARGET_DIR/.claude/skills/$pkg"
  else
    echo "  [warn] $pkg not found. Run: npx skillpm install @campforge/$pkg"
  fi
done

# 4. Identity -> CLAUDE.md
{
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  echo "---"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 5. Knowledge
if [ -d "$CAMP_DIR/knowledge" ]; then
  cp -r "$CAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

echo ":: CampForge iap-manager installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
