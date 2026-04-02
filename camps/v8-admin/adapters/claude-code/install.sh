#!/bin/bash
# CampForge v8-admin adapter for Claude Code

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$CAMP_DIR/../.." && pwd)"
TARGET_DIR="${1:-.}"

# 1. Ensure skill dependencies are resolved
cd "$REPO_ROOT" && npx skillpm install

# 2. Copy camp's declared skill dependencies to target
mkdir -p "$TARGET_DIR/.claude/skills" "$TARGET_DIR/.claude"
installed=0
if [ -d "$REPO_ROOT/node_modules/@campforge" ]; then
  for pkg_dir in "$REPO_ROOT/node_modules/@campforge"/*/; do
    pkg_name=$(basename "$pkg_dir")
    if grep -q "\"@campforge/$pkg_name\"" "$CAMP_DIR/package.json" 2>/dev/null; then
      [ -d "$pkg_dir/skills/$pkg_name" ] && rm -rf "$TARGET_DIR/.claude/skills/$pkg_name" && cp -rL "$pkg_dir/skills/$pkg_name" "$TARGET_DIR/.claude/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
# Fallback: copy from packages/ (local dev without skillpm install)
if [ "$installed" -eq 0 ] && [ -d "$REPO_ROOT/packages" ]; then
  for pkg_name in $(grep -o '"@campforge/[^"]*"' "$CAMP_DIR/package.json" 2>/dev/null | tr -d '"' | sed 's|@campforge/||'); do
    if [ -d "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" ]; then
      rm -rf "$TARGET_DIR/.claude/skills/$pkg_name" && cp -rL "$REPO_ROOT/packages/$pkg_name/skills/$pkg_name" "$TARGET_DIR/.claude/skills/$pkg_name" && installed=$((installed + 1))
    fi
  done
fi
if [ "$installed" -eq 0 ]; then
  echo "  [warn] No skills installed. Run: cd $REPO_ROOT && npx skillpm install"
fi

# 3. Identity -> CLAUDE.md
mkdir -p "$TARGET_DIR/.claude"
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
  # gws: prefer musl binary on Linux (avoids glibc >=2.39 requirement from gnu build)
  if [ "$(uname -s)" = "Linux" ]; then
    GWS_VERSION=$(curl -fsSL https://api.github.com/repos/googleworkspace/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  GWS_TARGET="x86_64-unknown-linux-musl" ;;
      aarch64) GWS_TARGET="aarch64-unknown-linux-musl" ;;
      *)       GWS_TARGET="" ;;
    esac
    if [ -n "$GWS_TARGET" ] && [ -n "$GWS_VERSION" ]; then
      curl -fsSL "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" | tar xz -C /usr/local/bin gws && \
        chmod +x /usr/local/bin/gws || echo "  [warn] gws musl binary install failed."
    else
      npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
    fi
  else
    npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
  fi
  # gws-auth
  npm install -g https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws-auth install failed. Install manually: npm i -g https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz"
fi

echo ":: CampForge v8-admin installed for Claude Code"
echo "   Skills: $(ls "$TARGET_DIR/.claude/skills" 2>/dev/null | wc -l | tr -d ' ') installed"
echo "   Identity: .claude/CLAUDE.md created"
