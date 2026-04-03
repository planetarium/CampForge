#!/usr/bin/env bash
# E2E test: verify camp installers include identity/knowledge files.
#
# Usage:
#   ./scripts/test-install.sh              # Test all camps
#   ./scripts/test-install.sh v8-admin     # Test a specific camp
#
# Requires: docker
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMPS=("${@:-v8-admin 9c-backoffice campforge-guide}")
# If no args, expand the default string into array
if [ $# -eq 0 ]; then
  CAMPS=(v8-admin 9c-backoffice campforge-guide)
fi

PASS=0
FAIL=0

for CAMP in "${CAMPS[@]}"; do
  echo ""
  echo "========================================="
  echo "  Testing camp: $CAMP"
  echo "========================================="

  CAMP_DIR="$REPO_ROOT/camps/$CAMP"
  [ -f "$CAMP_DIR/install.sh" ] || { echo "  [skip] no install.sh"; continue; }

  # 1. Pack tarballs (use repo-local path for Docker mount compatibility on macOS)
  DIST="$REPO_ROOT/dist/test-$CAMP"
  rm -rf "$DIST"
  mkdir -p "$DIST"
  bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > /dev/null 2>&1

  # 2. Build a test install script: replace BASE with local server URL
  #    and skip post-install binaries (gws/gws-auth) that aren't relevant to this test
  sed \
    -e 's|^BASE=.*|BASE="http://localhost:8080"|' \
    -e 's|^install_gws$|# skip: install_gws|' \
    -e 's|^install_gws_auth$|# skip: install_gws_auth|' \
    "$CAMP_DIR/install.sh" > "$DIST/install.sh"

  # 3. Collect expected camp files from the source camp directory
  EXPECTED=()
  for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md knowledge/glossary.md manifest.yaml; do
    [ -f "$CAMP_DIR/$f" ] && EXPECTED+=("$f")
  done

  # 4. Run in Docker
  echo "  Running installer in Docker..."
  RESULT=$(docker run --rm \
    -v "$DIST:/srv" \
    node:20 bash -c '
      # Start a file server in background
      npx --yes serve /srv -p 8080 --no-clipboard -s 2>/dev/null &
      SERVER_PID=$!
      # Wait for server to be ready
      for i in $(seq 1 10); do
        curl -sf http://localhost:8080/ >/dev/null 2>&1 && break
        sleep 0.5
      done
      # Run the camp installer
      cd /tmp
      bash /srv/install.sh 2>&1
      # Output installed files for verification
      echo "---INSTALLED_FILES---"
      find workspace -type f \( -name "*.md" -o -name "*.yaml" \) 2>/dev/null | sort
      kill $SERVER_PID 2>/dev/null
    ' 2>&1) || true

  # 5. Verify expected files
  echo "  Verifying installed files..."
  CAMP_PASS=true
  for f in "${EXPECTED[@]}"; do
    if echo "$RESULT" | grep -q "workspace/$f"; then
      echo "    ✓ $f"
    else
      echo "    ✗ $f  MISSING"
      CAMP_PASS=false
    fi
  done

  if $CAMP_PASS; then
    echo "  => PASS"
    PASS=$((PASS + 1))
  else
    echo "  => FAIL"
    echo "  --- Docker output ---"
    echo "$RESULT" | tail -30
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
