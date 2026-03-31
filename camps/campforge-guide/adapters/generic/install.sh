#!/bin/bash
# CampForge adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy camp skills
mkdir -p "$TARGET_DIR/.agents/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.agents/skills/$skill_name"
done

echo ":: CampForge campforge-guide installed (generic)"
