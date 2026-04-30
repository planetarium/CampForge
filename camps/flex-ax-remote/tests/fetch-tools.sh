#!/usr/bin/env bash
# Pre-fetch external CLI tools for E2E testing.
set -euo pipefail

DIST="${1:?Usage: fetch-tools.sh <dist-dir>}"
mkdir -p "$DIST"

A2X_VERSION="${A2X_VERSION:-0.2.0}"
A2X_TAG="cli-v${A2X_VERSION}"

case "$(uname -m)" in
  x86_64)         A2X_ASSET="a2x-linux-x64" ;;
  arm64|aarch64)  A2X_ASSET="a2x-linux-arm64" ;;
  *) exit 0 ;;
esac

if [ ! -f "$DIST/$A2X_ASSET" ]; then
  gh release download "$A2X_TAG" --repo planetarium/a2x \
    --pattern "$A2X_ASSET" --dir "$DIST" 2>/dev/null || exit 0
fi

echo "a2x|${A2X_ASSET}|curl -fsSL {file} -o /usr/local/bin/a2x; chmod +x /usr/local/bin/a2x"
