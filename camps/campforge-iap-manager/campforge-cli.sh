#!/bin/bash
# CampForge iap-manager — one-shot install script
set -e

CAMP_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

echo "=== CampForge iap-manager Camp Installer ==="
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
