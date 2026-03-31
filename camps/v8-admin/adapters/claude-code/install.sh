#!/bin/bash
# CampForge v8-admin adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy skills
mkdir -p "$TARGET_DIR/.claude/skills"
cp -r "$CAMP_DIR/skills/v8-admin" "$TARGET_DIR/.claude/skills/v8-admin"

# Copy gws-sheets (optional)
if [ -d "$CAMP_DIR/skills/gws-sheets" ]; then
  cp -r "$CAMP_DIR/skills/gws-sheets" "$TARGET_DIR/.claude/skills/gws-sheets"
fi

# Copy gql-ops: skillpm (node_modules) → local fallback (packages/)
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
else
  echo "  [warn] gql-ops not found. Install via: skillpm install @campforge/gql-ops"
fi

# 3. Identity -> CLAUDE.md
{
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  echo "---"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 4. Knowledge
if [ -d "$CAMP_DIR/knowledge" ]; then
  cp -r "$CAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

# 5. Install gws + gws-auth (for gws-sheets skill)
if [ -d "$TARGET_DIR/.claude/skills/gws-sheets" ]; then
  echo ":: Installing gws and gws-auth..."
  npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws/gws-auth install failed. Install manually: npm i -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz"
fi

echo ":: CampForge v8-admin installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
