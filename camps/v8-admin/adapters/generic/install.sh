#!/bin/bash
# CampForge v8-admin adapter — generic fallback

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
      [ -d "$pkg_dir/skills/$pkg_name" ] && rm -rf "$TARGET_DIR/.agents/skills/$pkg_name" && cp -rL "$pkg_dir/skills/$pkg_name" "$TARGET_DIR/.agents/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
if [ "$installed" -eq 0 ] && [ -d "$REPO_ROOT/packages" ]; then
  for pkg_name in $(grep -o '"@campforge/[^"]*"' "$CAMP_DIR/package.json" 2>/dev/null | tr -d '"' | sed 's|@campforge/||'); do
    if [ -d "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" ]; then
      rm -rf "$TARGET_DIR/.agents/skills/$pkg_name" && cp -rL "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" "$TARGET_DIR/.agents/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
if [ "$installed" -eq 0 ]; then
  echo "  [warn] No skills installed. Run: cd $REPO_ROOT && npx skillpm install"
fi

# 3. Install gws + gws-auth (for gws-sheets skill)
if [ -d "$TARGET_DIR/.agents/skills/gws-sheets" ]; then
  npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws/gws-auth install failed. Install manually."
fi

echo ":: CampForge v8-admin installed (generic)"
