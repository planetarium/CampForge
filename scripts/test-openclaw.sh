#!/usr/bin/env bash
# E2E test: verify that OpenClaw recognizes skills installed by camp installers.
#
# This test installs a camp inside a Docker container with OpenClaw pre-installed,
# then checks `openclaw skills list` to confirm skill discovery.
#
# Usage:
#   ./scripts/test-openclaw.sh              # Test all camps
#   ./scripts/test-openclaw.sh v8-admin     # Test a specific camp
#
# Requires: docker, docker compose, node
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$REPO_ROOT/scripts/test-openclaw"
CAMPS=("$@")
if [ ${#CAMPS[@]} -eq 0 ]; then
  CAMPS=(v8-admin 9c-backoffice campforge-guide)
fi

PASS=0
FAIL=0

# Build the openclaw test image once
echo "Building OpenClaw test image..."
docker compose -f "$COMPOSE_DIR/docker-compose.yml" build --quiet 2>&1

for CAMP in "${CAMPS[@]}"; do
  echo ""
  echo "========================================="
  echo "  Testing camp: $CAMP (OpenClaw)"
  echo "========================================="

  CAMP_DIR="$REPO_ROOT/camps/$CAMP"
  [ -f "$CAMP_DIR/install.sh" ] || { echo "  [skip] no install.sh"; continue; }

  # 1. Pack tarballs
  DIST="$REPO_ROOT/dist/test-openclaw-$CAMP"
  rm -rf "$DIST"
  mkdir -p "$DIST"
  PACK_LOG="$DIST/release-pack.log"
  if ! bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > "$PACK_LOG" 2>&1; then
    echo "  [error] release-pack.sh failed for $CAMP"
    cat "$PACK_LOG"
    FAIL=$((FAIL + 1))
    rm -rf "$DIST"
    continue
  fi
  rm -f "$PACK_LOG"

  # 2. Build test install script: replace BASE with local server
  sed \
    -e 's|^BASE=.*|BASE="http://localhost:8080"|' \
    "$CAMP_DIR/install.sh" > "$DIST/install.sh"

  # 3. Collect expected skill names from camp dependencies
  EXPECTED_SKILLS=$(node -e "
    const pkg = require('$CAMP_DIR/package.json');
    Object.keys(pkg.dependencies || {})
      .filter(d => d.startsWith('@campforge/'))
      .forEach(d => console.log(d.slice('@campforge/'.length)));
  ")
  if [ -z "$EXPECTED_SKILLS" ]; then
    echo "  [error] no expected @campforge/* skills found for $CAMP; cannot verify OpenClaw discovery"
    FAIL=$((FAIL + 1))
    rm -rf "$DIST"
    continue
  fi

  # 4. Run in Docker with OpenClaw
  echo "  Running installer + OpenClaw skill check in Docker..."
  DOCKER_EXIT=0
  if RESULT=$(DIST_DIR="$DIST" docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
    run --rm -T \
    test-openclaw 2>&1); then
    :
  else
    DOCKER_EXIT=$?
  fi

  if [ "$DOCKER_EXIT" -ne 0 ]; then
    echo "  [error] Docker/OpenClaw test failed for $CAMP (exit code: $DOCKER_EXIT)"
    echo "  --- Docker output (last 40 lines) ---"
    echo "$RESULT" | tail -40
    echo "  ---------------------"
    FAIL=$((FAIL + 1))
    rm -rf "$DIST"
    continue
  fi

  # 5. Verify: check openclaw skills list output for each expected skill
  #    Extract only the "openclaw skills list" section to avoid matching install logs
  echo "  Verifying OpenClaw skill recognition..."
  CAMP_PASS=true
  SKILLS_OUTPUT=$(echo "$RESULT" | sed -n '/=== OpenClaw skill recognition ===/,$p')

  for skill in $EXPECTED_SKILLS; do
    if echo "$SKILLS_OUTPUT" | grep -q "✓ ready" && echo "$SKILLS_OUTPUT" | grep "✓ ready" | grep -Fqi "$skill"; then
      echo "    ✓ $skill (ready)"
    elif echo "$SKILLS_OUTPUT" | grep -Fqi "$skill"; then
      echo "    △ $skill (listed but not ready)"
      CAMP_PASS=false
    else
      echo "    ✗ $skill  NOT RECOGNIZED"
      CAMP_PASS=false
    fi
  done

  if $CAMP_PASS; then
    echo "  => PASS"
    PASS=$((PASS + 1))
  else
    echo "  => FAIL"
    echo "  --- Docker output (last 40 lines) ---"
    echo "$RESULT" | tail -40
    echo "  ---------------------"
    FAIL=$((FAIL + 1))
  fi

  rm -rf "$DIST"
done

echo ""
echo "========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================="
[ "$FAIL" -eq 0 ]
