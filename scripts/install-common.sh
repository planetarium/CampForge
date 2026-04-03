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

    # Extract only allowed top-level entries
    tar xzf "$tmp_tar" -C "$extract_dir" --no-same-owner --no-same-permissions \
      $allowed_entries 2>/dev/null || true

    for entry in $allowed_entries; do
      [ -e "$extract_dir/$entry" ] || continue
      # Reject symlinks
      if [ -L "$extract_dir/$entry" ]; then
        echo "  [warn] Skipping symlink: $entry" >&2
        continue
      fi
      rm -rf "./$entry"
      cp -R "$extract_dir/$entry" "./$entry"
      copied=1
    done

    if [ "$copied" -ne 1 ]; then
      echo "  [warn] No expected camp files found in archive." >&2
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

