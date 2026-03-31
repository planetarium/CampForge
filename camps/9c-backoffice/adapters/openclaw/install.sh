#!/bin/bash
# CampForge 9c-backoffice adapter for OpenClaw

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

# 1. Install all skills via skillpm
cd "$CAMP_DIR" && npx skillpm install

# 2. Identity files (backup first)
for f in SOUL.md IDENTITY.md AGENTS.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  fi
  if [ -f "$CAMP_DIR/identity/$f" ]; then
    cp "$CAMP_DIR/identity/$f" "$WORKSPACE/$f"
  fi
done

# 3. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo ":: CampForge 9c-backoffice installed for OpenClaw"
