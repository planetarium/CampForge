#!/usr/bin/env bash
# Pre-fetch external CLI tools for E2E testing.
# Called by test-install.sh on the host before Docker runs.
#
# Usage: ./fetch-tools.sh <dist-dir>
#   Downloads tool binaries into <dist-dir> so they can be served
#   via a local HTTP server inside Docker.
#
# Outputs one line per tool: <tool-name>|<filename>|<install-command>
# The install command uses {file} as a placeholder for the local URL.
set -euo pipefail

DIST="${1:?Usage: fetch-tools.sh <dist-dir>}"

A2X_VERSION="${A2X_VERSION:-0.2.0}"
A2X_TAG="cli-v${A2X_VERSION}"
A2X_ASSET="a2x-linux-x64"

if [ ! -f "$DIST/$A2X_ASSET" ]; then
  gh release download "$A2X_TAG" --repo planetarium/a2x \
    --pattern "$A2X_ASSET" --dir "$DIST" 2>/dev/null || {
    echo "  [warn] a2x download failed (gh auth?)" >&2
    exit 0
  }
fi

# Install: copy the binary into a PATH dir and chmod +x.
echo "a2x|${A2X_ASSET}|install -m 0755 {file} /usr/local/bin/a2x"
