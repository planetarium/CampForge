#!/bin/bash
# CampForge campforge-guide adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Ensure skill dependencies are resolved
cd "$REPO_ROOT" && npx skillpm install

# 2. Copy camp's declared skill dependencies
mkdir -p "$TARGET_DIR/.agents/skills"
installed=0
if [ -d "$REPO_ROOT/node_modules/@campforge" ]; then
  for pkg_dir in "$REPO_ROOT/node_modules/@campforge"/*/; do
    pkg_name=$(basename "$pkg_dir")
    if grep -q "\"@campforge/$pkg_name\"" "$CAMP_DIR/package.json" 2>/dev/null; then
      [ -d "$pkg_dir/skills/$pkg_name" ] && cp -rL "$pkg_dir/skills/$pkg_name" "$TARGET_DIR/.agents/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
if [ "$installed" -eq 0 ] && [ -d "$REPO_ROOT/packages" ]; then
  for pkg_name in $(grep -o '"@campforge/[^"]*"' "$CAMP_DIR/package.json" 2>/dev/null | tr -d '"' | sed 's|@campforge/||'); do
    if [ -d "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" ]; then
      cp -rL "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" "$TARGET_DIR/.agents/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
if [ "$installed" -eq 0 ]; then
  echo "  [warn] No skills installed. Run: cd $REPO_ROOT && npx skillpm install"
fi

echo ":: CampForge campforge-guide installed (generic)"
