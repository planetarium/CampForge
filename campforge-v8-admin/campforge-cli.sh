#!/bin/bash
# CampForge v8-admin — one-shot install script
set -e

CAMP_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

echo "=== CampForge v8-admin Camp Installer ==="
echo ""

# 1. Detect agent platform
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

# 2. Run adapter
echo "[2/3] Installing..."
bash "$CAMP_DIR/adapters/$PLATFORM/install.sh" "$TARGET_DIR"

# 3. Smoke test hint
echo ""
echo "[3/3] Installation complete!"
echo ""
echo "  Run smoke test:"
echo "    \"v8-admin smoke test를 실행해줘\""
echo ""
echo "  Or load the test scenario:"
echo "    tests/smoke-test.md"
