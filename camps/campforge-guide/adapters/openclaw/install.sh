#!/bin/bash
# CampForge campforge-guide adapter for OpenClaw

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

# 1. Ensure skill dependencies are resolved
cd "$REPO_ROOT" && npx skillpm install

# 2. Identity files (backup first)
for f in SOUL.md IDENTITY.md AGENTS.md; do
  [ -f "$WORKSPACE/$f" ] && cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  [ -f "$CAMP_DIR/identity/$f" ] && cp "$CAMP_DIR/identity/$f" "$WORKSPACE/$f"
done

# 3. Copy camp's declared skill dependencies
mkdir -p "$WORKSPACE/skills"
if [ -d "$REPO_ROOT/node_modules/@campforge" ]; then
for pkg_dir in "$REPO_ROOT/node_modules/@campforge"/*/; do
  pkg_name=$(basename "$pkg_dir")
  if grep -q "\"@campforge/$pkg_name\"" "$CAMP_DIR/package.json" 2>/dev/null; then
    [ -d "$pkg_dir/skills/$pkg_name" ] && cp -rL "$pkg_dir/skills/$pkg_name" "$WORKSPACE/skills/$pkg_name"
  fi
done
fi

# 4. Gateway restart
command -v openclaw &> /dev/null && openclaw gateway restart 2>/dev/null || true

echo ":: CampForge campforge-guide installed for OpenClaw"
