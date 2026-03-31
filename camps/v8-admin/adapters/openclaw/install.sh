#!/bin/bash
# CampForge v8-admin adapter for OpenClaw

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Identity files (backup first)
for f in SOUL.md IDENTITY.md AGENTS.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  fi
  if [ -f "$CAMP_DIR/identity/$f" ]; then
    cp "$CAMP_DIR/identity/$f" "$WORKSPACE/$f"
  fi
done

# 3. Skills
mkdir -p "$WORKSPACE/skills"
cp -r "$CAMP_DIR/skills/v8-admin" "$WORKSPACE/skills/v8-admin"

# gws-sheets (optional)
if [ -d "$CAMP_DIR/skills/gws-sheets" ]; then
  cp -r "$CAMP_DIR/skills/gws-sheets" "$WORKSPACE/skills/gws-sheets"
fi

# gql-ops: skillpm → local fallback
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
fi

# 4. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

# 5. Install gws + gws-auth (for gws-sheets skill)
if [ -d "$WORKSPACE/skills/gws-sheets" ]; then
  npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws/gws-auth install failed. Install manually."
fi

echo ":: CampForge v8-admin installed for OpenClaw"
