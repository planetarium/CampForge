#!/bin/bash
# CampForge v8-admin adapter — generic fallback

BOOTCAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$BOOTCAMP_DIR" && skillpm install)
fi

# 2. Copy skills only
mkdir -p "$TARGET_DIR/.agents/skills"
cp -r "$BOOTCAMP_DIR/skills/v8-admin" "$TARGET_DIR/.agents/skills/v8-admin"

# gql-ops: skillpm → local fallback
if [ -d "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
elif [ -d "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$BOOTCAMP_DIR/../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
fi

echo ":: CampForge v8-admin installed (generic)"
