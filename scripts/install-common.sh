#!/usr/bin/env bash
# Common installation functions for CampForge camps.
# Sourced by each camp's install.sh — not executed directly.

# Install Google Workspace CLI (gws).
# Prefers musl static binary on Linux to avoid glibc >=2.39 requirement.
install_gws() {
  echo ":: Installing gws..."
  if [ "$(uname -s)" = "Linux" ]; then
    GWS_VERSION=$(curl -fsSL https://api.github.com/repos/googleworkspace/cli/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  GWS_TARGET="x86_64-unknown-linux-musl" ;;
      aarch64) GWS_TARGET="aarch64-unknown-linux-musl" ;;
      *)       GWS_TARGET="" ;;
    esac
    GWS_BIN_DIR="${GWS_BIN_DIR:-${HOME}/.local/bin}"
    mkdir -p "$GWS_BIN_DIR"
    if [ -n "$GWS_TARGET" ] && [ -n "$GWS_VERSION" ]; then
      curl -fsSL "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" | tar xz --strip-components=0 -C "$GWS_BIN_DIR" ./gws && \
        chmod +x "$GWS_BIN_DIR/gws" || npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
    else
      npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
    fi
  else
    npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
  fi
}

# Install camp identity/knowledge/manifest/tests files from a tarball URL.
# Extracts into a temporary directory and copies only expected entries.
# Usage: install_camp_files <tarball-url>
install_camp_files() {
  local url="$1"
  local allowed_entries="identity knowledge tests manifest.yaml"

  echo ":: Installing camp files..."

  (
    local tmp_tar extract_dir copied=0 entry

    cleanup() { rm -f "$tmp_tar"; rm -rf "$extract_dir"; }

    tmp_tar="$(mktemp)"
    extract_dir="$(mktemp -d)"
    trap cleanup EXIT

    curl -fsSL "$url" -o "$tmp_tar"

    # Reject archives with path traversal or absolute paths
    if tar tzf "$tmp_tar" | grep -qE '(^/|\.\.)'; then
      echo "  [error] Archive contains unsafe paths, aborting." >&2
      exit 1
    fi

    # Extract only allowed top-level entries (ignore missing ones individually)
    for entry in $allowed_entries; do
      tar xzf "$tmp_tar" -C "$extract_dir" --no-same-owner --no-same-permissions \
        "$entry" 2>/dev/null || true
    done

    for entry in $allowed_entries; do
      [ -e "$extract_dir/$entry" ] || continue
      # Reject symlinks and hardlinks anywhere under the entry
      if find "$extract_dir/$entry" -type l -print -quit | grep -q .; then
        echo "  [error] Archive contains symlinks under: $entry" >&2
        exit 1
      fi
      if find "$extract_dir/$entry" ! -type d -links +1 -print -quit 2>/dev/null | grep -q .; then
        echo "  [error] Archive contains hardlinks under: $entry" >&2
        exit 1
      fi
      rm -rf "./$entry"
      cp -R "$extract_dir/$entry" "./$entry"
      copied=1
    done

    if [ "$copied" -ne 1 ]; then
      echo "  [error] No expected camp files found in archive: $url" >&2
      exit 1
    fi
  )
}

# Install gws-auth plugin.
install_gws_auth() {
  echo ":: Installing gws-auth..."
  npm install -g https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
    echo "  [warn] gws-auth install failed. Install manually: npm i -g https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz"
}

# ---------------------------------------------------------------------------
# Platform adapter: wire identity/knowledge files into the agent's context.
# ---------------------------------------------------------------------------

# Detect the current agent platform.
# Override with CAMPFORGE_PLATFORM env var.
detect_platform() {
  if [ -n "${CAMPFORGE_PLATFORM:-}" ]; then
    echo "$CAMPFORGE_PLATFORM"
    return
  fi

  if [ -d ".claude" ] || command -v claude >/dev/null 2>&1; then
    echo "claude-code"
  elif command -v openclaw >/dev/null 2>&1 || [ -n "${OPENCLAW_WORKSPACE:-}" ]; then
    echo "openclaw"
  elif command -v codex >/dev/null 2>&1 || [ -n "${CODEX_HOME:-}" ]; then
    echo "codex"
  else
    echo "claude-code"
  fi
}

# Generate platform-specific adapter files so that identity/ and knowledge/
# files are wired into the agent's context.
#
# Must be called from the workspace root after install_camp_files.
generate_adapters() {
  local platform
  platform="$(detect_platform)"

  # Collect identity and knowledge file paths
  local files=()
  for f in identity/*.md; do [ -f "$f" ] && files+=("$f"); done
  for f in knowledge/*.md; do [ -f "$f" ] && files+=("$f"); done
  for f in knowledge/decision-trees/*.md; do [ -f "$f" ] && files+=("$f"); done

  if [ ${#files[@]} -eq 0 ]; then
    return
  fi

  echo ":: Generating ${platform} adapter..."

  case "$platform" in
    claude-code)
      _adapter_claude_code "${files[@]}"
      ;;
    openclaw)
      _adapter_openclaw
      ;;
    codex)
      _adapter_codex
      ;;
    *)
      echo "  [warn] Unknown platform '${platform}', skipping adapter generation."
      ;;
  esac
}

# Claude Code: generate .claude/CLAUDE.md with @ references
_adapter_claude_code() {
  mkdir -p .claude
  {
    echo "# Camp Context"
    echo ""
    for f in "$@"; do
      echo "@${f}"
    done
  } > .claude/CLAUDE.md
  echo "  Created .claude/CLAUDE.md with ${#} @ references"
}

# OpenClaw: identity files are already in the right place (workspace root).
# Knowledge files need to be appended to AGENTS.md since OpenClaw only
# auto-loads a fixed set of top-level markdown files.
_adapter_openclaw() {
  if [ ! -f identity/AGENTS.md ]; then
    return
  fi

  local appended=0
  for f in knowledge/*.md knowledge/decision-trees/*.md; do
    if [ -f "$f" ]; then
      if [ $appended -eq 0 ]; then
        echo "" >> identity/AGENTS.md
        echo "---" >> identity/AGENTS.md
        echo "# Knowledge Reference" >> identity/AGENTS.md
        echo "" >> identity/AGENTS.md
        appended=1
      fi
      cat "$f" >> identity/AGENTS.md
      echo "" >> identity/AGENTS.md
    fi
  done

  if [ $appended -gt 0 ]; then
    echo "  Appended knowledge to identity/AGENTS.md"
  fi
}

# Codex: concatenate identity + knowledge into a root AGENTS.md.
# Respects Codex's 32 KiB default limit for project docs.
_adapter_codex() {
  local max_bytes="${CODEX_PROJECT_DOC_MAX_BYTES:-32000}"

  {
    # Identity files first
    for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md; do
      if [ -f "$f" ]; then
        cat "$f"
        echo ""
        echo "---"
        echo ""
      fi
    done

    # Knowledge files
    for f in knowledge/*.md knowledge/decision-trees/*.md; do
      if [ -f "$f" ]; then
        cat "$f"
        echo ""
      fi
    done
  } > AGENTS.md

  # Truncate if over limit
  local size
  size=$(wc -c < AGENTS.md)
  if [ "$size" -gt "$max_bytes" ]; then
    echo "  [warn] AGENTS.md (${size}B) exceeds ${max_bytes}B limit, truncating."
    head -c "$max_bytes" AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  fi

  echo "  Created AGENTS.md ($(wc -c < AGENTS.md)B)"
}

