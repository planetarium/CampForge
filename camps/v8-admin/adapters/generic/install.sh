#!/bin/bash
# CampForge v8-admin adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Resolve all skill dependencies
cd "$CAMP_DIR" && npx skillpm install 2>/dev/null || npm install 2>/dev/null || true

# 2. Copy skills from resolved packages
mkdir -p "$TARGET_DIR/.agents/skills"
for skill_dir in "$CAMP_DIR"/node_modules/@campforge/*/skills/*/; do
  [ -d "$skill_dir" ] && cp -r "$skill_dir" "$TARGET_DIR/.agents/skills/$(basename "$skill_dir")"
done

# 3. Install gws + gws-auth (for gws-sheets skill)
if [ -d "$TARGET_DIR/.agents/skills/gws-sheets" ]; then
  npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws/gws-auth install failed. Install manually."
fi

echo ":: CampForge v8-admin installed (generic)"
