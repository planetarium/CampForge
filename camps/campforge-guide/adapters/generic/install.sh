#!/bin/bash
# CampForge campforge-guide adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Resolve all skill dependencies
cd "$CAMP_DIR" && npx skillpm install 2>/dev/null || npm install 2>/dev/null || true

# 2. Copy skills from resolved packages
mkdir -p "$TARGET_DIR/.agents/skills"
for skill_dir in "$CAMP_DIR"/node_modules/@campforge/*/skills/*/; do
  [ -d "$skill_dir" ] && cp -r "$skill_dir" "$TARGET_DIR/.agents/skills/$(basename "$skill_dir")"
done

echo ":: CampForge campforge-guide installed (generic)"
