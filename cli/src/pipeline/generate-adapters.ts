import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import { chmodSync } from "node:fs";
import type { PipelineContext } from "../commands/create.js";

const claudeCodeInstall = `#!/bin/bash
# CampForge adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="\${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy skills
mkdir -p "$TARGET_DIR/.claude/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/$skill_name"
done

# Copy gql-ops: skillpm (node_modules) -> local fallback (packages/)
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.claude/skills/gql-ops"
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

echo ":: CampForge installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
`;

const openclawInstall = `#!/bin/bash
# CampForge adapter for OpenClaw

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="\${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

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
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$WORKSPACE/skills/$skill_name"
done

# gql-ops: skillpm -> local fallback
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$WORKSPACE/skills/gql-ops"
fi

# 4. Gateway restart
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo ":: CampForge installed for OpenClaw"
`;

const genericInstall = `#!/bin/bash
# CampForge adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="\${1:-.}"

# 1. Install skill dependencies via skillpm
if command -v skillpm &> /dev/null; then
  (cd "$CAMP_DIR" && skillpm install)
fi

# 2. Copy skills only
mkdir -p "$TARGET_DIR/.agents/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.agents/skills/$skill_name"
done

# gql-ops: skillpm -> local fallback
if [ -d "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/node_modules/@campforge/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
elif [ -d "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" ]; then
  cp -r "$CAMP_DIR/../../packages/gql-ops/skills/gql-ops" "$TARGET_DIR/.agents/skills/gql-ops"
fi

echo ":: CampForge installed (generic)"
`;

const codexInstall = `#!/bin/bash
# CampForge adapter for Codex

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="\${1:-.}"

mkdir -p "$TARGET_DIR/.codex/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.codex/skills/$skill_name"
done

# Identity -> AGENTS.md
{
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.codex/AGENTS.md"

echo ":: CampForge installed for Codex"
`;

const geminiInstall = `#!/bin/bash
# CampForge adapter for Gemini CLI

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="\${1:-.}"

mkdir -p "$TARGET_DIR/.gemini/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.gemini/skills/$skill_name"
done

echo ":: CampForge installed for Gemini CLI"
`;

const ADAPTERS: Record<string, string> = {
  "claude-code": claudeCodeInstall,
  openclaw: openclawInstall,
  generic: genericInstall,
  codex: codexInstall,
  "gemini-cli": geminiInstall,
};

export function generateAdapters(ctx: PipelineContext): void {
  for (const adapter of ctx.adapters) {
    const content = ADAPTERS[adapter];
    if (!content) continue;
    const path = join(ctx.outputDir, "adapters", adapter, "install.sh");
    writeFile(path, content);
    chmodSync(path, 0o755);
  }

  // campforge-cli.sh
  const domainId = ctx.domainSpec.domain.id;
  const cliSh = `#!/bin/bash
# CampForge ${domainId} — one-shot install script
set -e

CAMP_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="\${1:-.}"

echo "=== CampForge ${domainId} Camp Installer ==="
echo ""

detect_platform() {
  if [ -d "$TARGET_DIR/.claude" ] || command -v claude &> /dev/null; then
    echo "claude-code"
  elif [ -d "$HOME/.openclaw" ] || command -v openclaw &> /dev/null; then
    echo "openclaw"
  else
    echo "generic"
  fi
}

PLATFORM=$(detect_platform)
echo "[1/3] Detected platform: $PLATFORM"

echo "[2/3] Installing..."
bash "$CAMP_DIR/adapters/$PLATFORM/install.sh" "$TARGET_DIR"

echo ""
echo "[3/3] Installation complete!"
`;
  const cliPath = join(ctx.outputDir, "campforge-cli.sh");
  writeFile(cliPath, cliSh);
  chmodSync(cliPath, 0o755);
}
