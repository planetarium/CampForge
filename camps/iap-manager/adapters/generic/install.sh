#!/bin/bash
# CampForge iap-manager adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"

# 1. Resolve skill dependencies via skillpm
npx skillpm install 2>/dev/null || true

# 2. Copy camp skills
mkdir -p "$TARGET_DIR/.agents/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.agents/skills/$skill_name"
done

# 3. Copy shared skill dependencies (skillpm node_modules → local packages/ fallback)
for pkg in gql-ops; do
  if [ -d "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" ]; then
    cp -r "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" "$TARGET_DIR/.agents/skills/$pkg"
  elif [ -d "$REPO_ROOT/packages/$pkg/skills/$pkg" ]; then
    cp -r "$REPO_ROOT/packages/$pkg/skills/$pkg" "$TARGET_DIR/.agents/skills/$pkg"
  fi
done

echo ":: CampForge iap-manager installed (generic)"
