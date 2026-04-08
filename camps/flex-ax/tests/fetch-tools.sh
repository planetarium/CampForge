#!/usr/bin/env bash
# Pre-fetch external CLI tools for E2E testing.
# Called by test-install.sh on the host before Docker runs.
#
# Usage: ./fetch-tools.sh <dist-dir>
#   Downloads tool tarballs into <dist-dir> so they can be served
#   via a local HTTP server inside Docker.
#
# Outputs one line per tool: <tool-name>|<filename>|<install-command>
# The install command uses {file} as a placeholder for the local URL.
set -euo pipefail

DIST="${1:?Usage: fetch-tools.sh <dist-dir>}"

FLEX_AX_VERSION="${FLEX_AX_VERSION:-0.2.1}"
FLEX_AX_TAG="flex-cli@${FLEX_AX_VERSION}"
FLEX_AX_TGZ="flex-ax-${FLEX_AX_VERSION}.tgz"

if [ ! -f "$DIST/$FLEX_AX_TGZ" ]; then
  gh release download "$FLEX_AX_TAG" --repo planetarium/flex-ax \
    --pattern '*.tgz' --dir "$DIST" 2>/dev/null || {
    echo "  [warn] flex-ax download failed (gh auth?)" >&2
    exit 0
  }
fi

echo "flex-ax|${FLEX_AX_TGZ}|npm install -g {file}"
