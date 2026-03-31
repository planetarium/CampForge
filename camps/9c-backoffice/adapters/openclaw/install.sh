#!/bin/bash
# CampForge 9c-backoffice adapter for OpenClaw

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"

# 1. Resolve skill dependencies via skillpm
npx skillpm install 2>/dev/null || true

# 2. Identity files (backup first)
for f in SOUL.md IDENTITY.md AGENTS.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  fi
  if [ -f "$CAMP_DIR/identity/$f" ]; then
    cp "$CAMP_DIR/identity/$f" "$WORKSPACE/$f"
  fi
done

# 3. Copy camp skills
mkdir -p "$WORKSPACE/skills"
cp -r "$CAMP_DIR/skills/9c-backoffice" "$WORKSPACE/skills/9c-backoffice"

# 4. Copy shared skill dependencies (skillpm node_modules → local packages/ fallback)
for pkg in gql-ops; do
  if [ -d "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" ]; then
    cp -r "$CAMP_DIR/node_modules/@campforge/$pkg/skills/$pkg" "$WORKSPACE/skills/$pkg"
  elif [ -d "$REPO_ROOT/packages/$pkg/skills/$pkg" ]; then
    cp -r "$REPO_ROOT/packages/$pkg/skills/$pkg" "$WORKSPACE/skills/$pkg"
  fi
done

# 5. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo ":: CampForge 9c-backoffice installed for OpenClaw"
