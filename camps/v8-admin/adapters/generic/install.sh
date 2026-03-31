#!/bin/bash
# CampForge v8-admin adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy skills only
mkdir -p "$TARGET_DIR/.agents/skills"
cp -r "$CAMP_DIR/skills/v8-admin" "$TARGET_DIR/.agents/skills/v8-admin"

# gws-sheets (optional)
if [ -d "$CAMP_DIR/skills/gws-sheets" ]; then
  cp -r "$CAMP_DIR/skills/gws-sheets" "$TARGET_DIR/.agents/skills/gws-sheets"
fi

# gql-ops: skillpm → local fallback
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
fi

# 3. Install gws + gws-auth (for gws-sheets skill)
if [ -d "$TARGET_DIR/.agents/skills/gws-sheets" ]; then
  npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws/gws-auth install failed. Install manually."
fi

echo ":: CampForge v8-admin installed (generic)"
