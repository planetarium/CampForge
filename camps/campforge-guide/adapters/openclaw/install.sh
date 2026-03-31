#!/bin/bash
# CampForge adapter for OpenClaw

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

# 3. Copy camp skills
mkdir -p "$WORKSPACE/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$WORKSPACE/skills/$skill_name"
done

# 4. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo ":: CampForge campforge-guide installed for OpenClaw"
