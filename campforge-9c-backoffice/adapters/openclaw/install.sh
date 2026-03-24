#!/bin/bash
# CampForge 9c-backoffice adapter for OpenClaw

BOOTCAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$BOOTCAMP_DIR" && skillpm install)
fi

# 2. Identity files (backup first)
for f in SOUL.md IDENTITY.md AGENTS.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  fi
  if [ -f "$BOOTCAMP_DIR/identity/$f" ]; then
    cp "$BOOTCAMP_DIR/identity/$f" "$WORKSPACE/$f"
  fi
done

# 3. Skills
mkdir -p "$WORKSPACE/skills"
cp -r "$BOOTCAMP_DIR/skills/9c-backoffice" "$WORKSPACE/skills/9c-backoffice"

# gql-ops: skillpm → local fallback
if [ -d "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
elif [ -d "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
fi

# 4. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo ":: CampForge 9c-backoffice installed for OpenClaw"
