#!/usr/bin/env bash
# HEAD-check every URL referenced in camps/*/install.sh against actual GitHub Releases.
#
# Catches: CAMP_VERSION points to a tag that was never cut, or an asset is missing
# from the release. Does NOT check internal consistency (see validate-install-consistency.js).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_BASE="https://github.com/planetarium/CampForge/releases/download"

FAIL=0
CHECKED=0
FAILURES=()

check_url() {
  local url="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -I -L --max-time 15 "$url" || echo "000")
  CHECKED=$((CHECKED + 1))
  if [ "$code" = "200" ]; then
    echo "  [200] $url"
  else
    echo "  [$code] $url"
    FAILURES+=("[$code] $url")
    FAIL=$((FAIL + 1))
  fi
}

for camp_dir in "$REPO_ROOT"/camps/*/; do
  camp=$(basename "$camp_dir")
  install="$camp_dir/install.sh"
  [ -f "$install" ] || continue

  ver=$(sed -nE 's/^CAMP_VERSION="?\$\{CAMP_VERSION:-([^}]+)\}"?/\1/p' "$install" | head -1)
  if [ -z "$ver" ]; then
    echo "=== $camp ==="
    echo "  [parse-error] could not extract CAMP_VERSION from $install"
    FAILURES+=("[$camp] could not parse CAMP_VERSION")
    FAIL=$((FAIL + 1))
    continue
  fi

  raw_base=$(sed -nE 's/^BASE="([^"]+)".*/\1/p' "$install" | head -1)
  if [ -z "$raw_base" ]; then
    echo "=== $camp ==="
    echo "  [parse-error] could not extract BASE from $install"
    FAILURES+=("[$camp] could not parse BASE")
    FAIL=$((FAIL + 1))
    continue
  fi
  base=$(printf '%s' "$raw_base" | sed -e "s|\${CAMP_VERSION}|$ver|g" -e "s|\$CAMP_VERSION|$ver|g")

  expected_base="${RELEASE_BASE}/${camp}-${ver}"
  if [ "$base" != "$expected_base" ]; then
    echo "=== $camp ($ver) ==="
    echo "  [base-mismatch] install.sh BASE resolves to '$base', expected '$expected_base'"
    FAILURES+=("[$camp] BASE mismatch: $base != $expected_base")
    FAIL=$((FAIL + 1))
    continue
  fi

  echo "=== $camp ($ver) ==="

  while IFS= read -r suffix; do
    [ -n "$suffix" ] && check_url "${base}/${suffix}"
  done < <(grep -oE '\$BASE/[^"[:space:]]+' "$install" | sed 's|\$BASE/||' | sort -u)
done

echo ""
echo "checked $CHECKED URL(s), $FAIL failure(s)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "FAILURES:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
