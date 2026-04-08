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

# Install flex-ax CLI from GitHub Release.
# Requires gh CLI or GITHUB_TOKEN for private repo access.
install_flex_ax() {
  local version="${FLEX_AX_VERSION:-0.1.0}"
  local tag="flex-cli@${version}"
  local tgz="flex-ax-${version}.tgz"
  local url="https://github.com/planetarium/flex-ax/releases/download/${tag}/${tgz}"

  echo ":: Installing flex-ax CLI (${tag})..."

  if command -v flex-ax >/dev/null 2>&1; then
    echo "  flex-ax already installed, skipping."
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" RETURN

  curl -fsSL "$url" -o "$tmp_dir/$tgz" 2>/dev/null || {
    echo "  [warn] flex-ax download failed from $url"
    return
  }

  npm install -g "$tmp_dir/$tgz" 2>/dev/null || {
    echo "  [warn] flex-ax npm install failed."
    return
  }

  echo "  flex-ax installed successfully."
}

# Install camp identity/knowledge/manifest/tests files from a tarball URL.
# Extracts into a temporary directory and copies only expected entries.
# Usage: install_camp_files <tarball-url>
install_camp_files() {
  local url="$1"
  local allowed_entries="identity knowledge tests scripts manifest.yaml"

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

  # Check openclaw/codex first — a .claude/ directory may exist from prior installs
  if command -v openclaw >/dev/null 2>&1 || [ -n "${OPENCLAW_WORKSPACE:-}" ]; then
    echo "openclaw"
  elif command -v codex >/dev/null 2>&1 || [ -n "${CODEX_HOME:-}" ]; then
    echo "codex"
  elif command -v claude >/dev/null 2>&1 || [ -f ".claude/CLAUDE.md" ]; then
    echo "claude-code"
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

# Write content to a unique staging file (.campforge-context*.md).
# Avoids overwriting previous staging files from prior installs.
# Sets STAGING_FILE variable for callers.
_write_staging() {
  local content="$1"
  STAGING_FILE=".campforge-context.md"
  if [ -e "$STAGING_FILE" ]; then
    STAGING_FILE="$(mktemp ".campforge-context-XXXXXX.md")"
  fi
  printf '%s\n' "$content" > "$STAGING_FILE"
}

# Claude Code: generate .claude/CLAUDE.md with @ references.
# If .claude/CLAUDE.md already exists, write to a staging file instead.
_adapter_claude_code() {
  local content
  content=$(printf "# Camp Context\n\n"; for f in "$@"; do printf "@%s\n" "$f"; done)

  mkdir -p .claude
  if [ -f .claude/CLAUDE.md ]; then
    _write_staging "$content"
    echo ""
    echo "  [action-required] Existing .claude/CLAUDE.md found."
    echo "  Camp context has been written to $STAGING_FILE"
    echo "  Please merge the @ references from $STAGING_FILE into .claude/CLAUDE.md,"
    echo "  then delete $STAGING_FILE."
  else
    printf '%s\n' "$content" > .claude/CLAUDE.md
    echo "  Created .claude/CLAUDE.md with $# @ references"
  fi
}

# OpenClaw: auto-loads SOUL.md, IDENTITY.md, AGENTS.md from workspace root.
# identity/ files must be copied to root. Knowledge is appended to AGENTS.md.
# If root files already exist, stage camp content for manual merge.
_adapter_openclaw() {
  # Guide: OpenClaw needs skills.load.extraDirs to discover .agents/skills/.
  if [ -d .agents/skills ]; then
    local agents_skills_abs openclaw_config
    agents_skills_abs="$(cd .agents/skills && pwd)"
    openclaw_config="$HOME/.openclaw/openclaw.json"
    echo ""
    if [ -f "$openclaw_config" ] && grep -Fq "\"$agents_skills_abs\"" "$openclaw_config"; then
      echo "  [info] OpenClaw skills path already present in ~/.openclaw/openclaw.json:"
      echo ""
      echo "    $agents_skills_abs"
      echo ""
    else
      echo "  [action-required] To let OpenClaw discover installed skills,"
      echo "  update ~/.openclaw/openclaw.json so skills.load.extraDirs includes:"
      echo ""
      echo "    $agents_skills_abs"
      echo ""
      echo "  If ~/.openclaw/openclaw.json does not exist yet, create it."
      echo "  If it already exists, merge/add this path under skills.load.extraDirs"
      echo "  and do not replace your whole existing OpenClaw configuration."
      echo ""
    fi
  fi

  # Copy identity files to workspace root (OpenClaw reads from root, not identity/)
  for f in SOUL.md IDENTITY.md; do
    [ -f "identity/$f" ] || continue
    if [ -f "$f" ]; then
      printf '\n\n---\n\n' >> "$f"
      cat "identity/$f" >> "$f"
      echo "  Appended identity/$f -> $f"
    else
      cp "identity/$f" "$f"
      echo "  Copied identity/$f -> $f"
    fi
  done

  # AGENTS.md gets identity + knowledge merged
  local agents_content=""
  if [ -f identity/AGENTS.md ]; then
    agents_content="$(cat identity/AGENTS.md)"
  fi

  local knowledge_content=""
  for f in knowledge/*.md knowledge/decision-trees/*.md; do
    if [ -f "$f" ]; then
      knowledge_content+="$(cat "$f")"$'\n\n'
    fi
  done

  if [ -n "$knowledge_content" ]; then
    if [ -n "$agents_content" ]; then
      agents_content+=$'\n\n---\n# Knowledge Reference\n\n'"$knowledge_content"
    else
      agents_content=$'# Knowledge Reference\n\n'"$knowledge_content"
    fi
  fi

  if [ -n "$agents_content" ]; then
    if [ -f AGENTS.md ]; then
      printf '\n\n---\n\n' >> AGENTS.md
      printf '%s\n' "$agents_content" >> AGENTS.md
      echo "  Appended identity + knowledge -> AGENTS.md"
    else
      printf '%s\n' "$agents_content" > AGENTS.md
      echo "  Created AGENTS.md with identity + knowledge"
    fi
  fi
}

# Codex: concatenate identity + knowledge into a root AGENTS.md.
# Respects Codex's 32 KiB default limit for project docs.
# If AGENTS.md already exists, write to a staging file instead.
_adapter_codex() {
  local max_bytes="${CODEX_PROJECT_DOC_MAX_BYTES:-32768}"

  local content
  content=$(
    for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md; do
      if [ -f "$f" ]; then
        cat "$f"
        echo ""
        echo "---"
        echo ""
      fi
    done
    for f in knowledge/*.md knowledge/decision-trees/*.md; do
      if [ -f "$f" ]; then
        cat "$f"
        echo ""
      fi
    done
  )

  if [ -f AGENTS.md ]; then
    _write_staging "$content"
    echo ""
    echo "  [action-required] Existing AGENTS.md found."
    echo "  Camp context has been written to $STAGING_FILE"
    echo "  Please merge the content from $STAGING_FILE into AGENTS.md"
    echo "  (keep total size under ${max_bytes}B for Codex),"
    echo "  then delete $STAGING_FILE."
  else
    printf '%s\n' "$content" > AGENTS.md
    # Truncate safely on line boundaries if over limit (preserves UTF-8)
    local size
    size=$(wc -c < AGENTS.md)
    if [ "$size" -gt "$max_bytes" ]; then
      echo "  [warn] AGENTS.md (${size}B) exceeds ${max_bytes}B limit, truncating on line boundaries."
      : > AGENTS.md.tmp
      local truncated_size=0 line line_bytes
      while IFS= read -r line || [ -n "$line" ]; do
        line_bytes=$(printf '%s\n' "$line" | wc -c)
        if [ $((truncated_size + line_bytes)) -le "$max_bytes" ]; then
          printf '%s\n' "$line" >> AGENTS.md.tmp
          truncated_size=$((truncated_size + line_bytes))
        else
          break
        fi
      done < AGENTS.md
      mv AGENTS.md.tmp AGENTS.md
    fi
    echo "  Created AGENTS.md ($(wc -c < AGENTS.md)B)"
  fi
}

