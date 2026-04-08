#!/usr/bin/env bash
# Common installation functions for CampForge camps.
# Sourced by each camp's install.sh — not executed directly.

# ---------------------------------------------------------------------------
# Windows / MSYS / Git Bash detection
# ---------------------------------------------------------------------------

# Returns 0 (true) if running on a Windows-like environment.
is_windows() {
  case "${OSTYPE:-}" in
    msys*|mingw*|cygwin*) return 0 ;;
  esac
  case "$(uname -s 2>/dev/null)" in
    MSYS*|MINGW*|CYGWIN*) return 0 ;;
  esac
  return 1
}

# Portable PATH append — uses ';' on Windows, ':' elsewhere.
path_append() {
  local dir="$1"
  if is_windows; then
    export PATH="$dir;$PATH"
  else
    export PATH="$dir:$PATH"
  fi
}

# Ensure npm's global prefix directory exists on Windows.
# On MSYS/Git Bash, `npm install --prefix` may fail if %APPDATA%/npm is absent.
ensure_npm_dir() {
  if is_windows && [ -n "${APPDATA:-}" ]; then
    mkdir -p "$APPDATA/npm" 2>/dev/null || true
  fi
}

# Create a CLI wrapper at $prefix/bin/<name> that invokes a Node script.
# On Windows this also generates a .cmd batch file so the tool is callable
# from cmd.exe and PowerShell.
#
# Usage: link_node_bin <prefix> <name> <path-to-js>
link_node_bin() {
  local prefix="$1" name="$2" cli_js="$3"
  mkdir -p "$prefix/bin"

  if is_windows; then
    # Compute the path from $prefix/bin to $cli_js relative through $prefix.
    # cli_js is always under $prefix/node_modules/..., so strip the prefix.
    local rel_js="${cli_js#"$prefix/"}"

    # .cmd wrapper for cmd.exe / PowerShell
    printf '@echo off\r\nnode "%%~dp0\\..\\%s" %%*\r\n' \
      "$(echo "$rel_js" | sed 's|/|\\|g')" \
      > "$prefix/bin/${name}.cmd"

    # Shell wrapper for Git Bash / MSYS users
    cat > "$prefix/bin/$name" <<SHEOF
#!/usr/bin/env bash
exec node "\$(dirname "\$0")/../${rel_js}" "\$@"
SHEOF
    chmod +x "$prefix/bin/$name" 2>/dev/null || true
  else
    ln -sf "$cli_js" "$prefix/bin/$name"
    chmod +x "$prefix/bin/$name"
  fi
}

# Install Google Workspace CLI (gws).
# Prefers musl static binary on Linux to avoid glibc >=2.39 requirement.
install_gws() {
  echo ":: Installing gws..."

  if command -v gws >/dev/null 2>&1; then
    echo "  gws already installed, skipping."
    return
  fi

  local prefix="$(pwd)/.local"
  mkdir -p "$prefix/bin"

  # Linux: try downloading pre-built binary first
  if [ "$(uname -s)" = "Linux" ]; then
    local gws_version arch target=""
    gws_version=$(curl -fsSL https://api.github.com/repos/googleworkspace/cli/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || true)
    arch=$(uname -m)
    case "$arch" in
      x86_64)  target="x86_64-unknown-linux-musl" ;;
      aarch64) target="aarch64-unknown-linux-musl" ;;
    esac
    if [ -n "$target" ] && [ -n "$gws_version" ]; then
      curl -fsSL "https://github.com/googleworkspace/cli/releases/download/v${gws_version}/google-workspace-cli-${target}.tar.gz" \
        | tar xz --strip-components=0 -C "$prefix/bin" ./gws && \
        chmod +x "$prefix/bin/gws" && \
        export PATH="$prefix/bin:$PATH" && \
        echo "  gws installed at $prefix/bin/gws" && return
    fi
  fi

  # Fallback: npm install to workspace-local prefix
  ensure_npm_dir
  npm install --prefix "$prefix" @googleworkspace/cli 2>/dev/null || {
    echo "  [warn] gws install failed."
    return
  }
  local cli_js="$prefix/node_modules/@googleworkspace/cli/run.js"
  if [ -f "$cli_js" ]; then
    link_node_bin "$prefix" "gws" "$cli_js"
  fi
  path_append "$prefix/bin"
  echo "  gws installed at $prefix/bin/gws"
}

# Install flex-ax CLI from GitHub Release.
# Requires gh CLI or GITHUB_TOKEN for private repo access.
install_flex_ax() {
  local version="${FLEX_AX_VERSION:-0.2.0}"
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

  # Install to workspace-local .local/ to avoid global PATH issues
  local prefix="$(pwd)/.local"
  mkdir -p "$prefix"
  ensure_npm_dir
  npm install --prefix "$prefix" "$tmp_dir/$tgz" 2>/dev/null || {
    echo "  [warn] flex-ax npm install failed."
    return
  }

  # Create wrapper in .local/bin for easy access
  local cli_js="$prefix/node_modules/flex-ax/dist/cli.js"
  if [ -f "$cli_js" ]; then
    link_node_bin "$prefix" "flex-ax" "$cli_js"
  fi

  path_append "$prefix/bin"
  echo "  flex-ax installed at $prefix/bin/flex-ax"
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
  local url="https://github.com/planetarium/gws-auth/releases/download/v0.4.0/planetarium-gws-auth-0.4.0.tgz"
  local prefix="$(pwd)/.local"
  mkdir -p "$prefix"
  ensure_npm_dir
  npm install --prefix "$prefix" "$url" 2>/dev/null || {
    echo "  [warn] gws-auth install failed. Install manually: npm i -g $url"
    return
  }
  local cli_js="$prefix/node_modules/@anthropic-kr/gws-auth/bin/gws-auth.js"
  if [ -f "$cli_js" ]; then
    link_node_bin "$prefix" "gws-auth" "$cli_js"
  fi
  path_append "$prefix/bin"
  echo "  gws-auth installed at $prefix/bin/gws-auth"
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

