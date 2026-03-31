#!/bin/bash
# CampForge iap-manager adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Ensure skill dependencies are resolved
cd "$REPO_ROOT" && npx skillpm install

# 2. Copy camp's declared skill dependencies to target
mkdir -p "$TARGET_DIR/.claude/skills"
for pkg_dir in "$REPO_ROOT/node_modules/@campforge"/*/; do
  pkg_name=$(basename "$pkg_dir")
  if grep -q "\"@campforge/$pkg_name\"" "$CAMP_DIR/package.json" 2>/dev/null; then
    [ -d "$pkg_dir/skills/$pkg_name" ] && cp -rL "$pkg_dir/skills/$pkg_name" "$TARGET_DIR/.claude/skills/$pkg_name"
  fi
done

# 3. Identity -> CLAUDE.md
mkdir -p "$TARGET_DIR/.claude"
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

echo ":: CampForge iap-manager installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" 2>/dev/null | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
