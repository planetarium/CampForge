#!/bin/bash
# Pack skill packages into tarballs for GitHub Release
#
# Usage:
#   ./scripts/release-pack.sh                  # Pack ALL packages (legacy)
#   ./scripts/release-pack.sh --camp v8-admin   # Pack only packages needed by a camp
#
# Then create a per-camp release:
#   gh release create v8-admin-v1.1.0 dist/tarballs/*.tgz dist/tarballs/install-common.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --camp) CAMP="$2"; shift 2 ;;
    *) break ;;
  esac
done

OUT="${1:-$REPO_ROOT/dist/tarballs}"
mkdir -p "$OUT"

# Determine which packages to pack
if [ -n "$CAMP" ]; then
  CAMP_DIR="$REPO_ROOT/camps/$CAMP"
  [ -f "$CAMP_DIR/package.json" ] || { echo "Camp not found: $CAMP"; exit 1; }

  echo "=== Packing packages for camp: $CAMP ==="
  # Extract @campforge/* dependency names from the camp's package.json
  DEPS=$(node -e "
    const pkg = require('$CAMP_DIR/package.json');
    const deps = pkg.dependencies || {};
    Object.keys(deps).forEach(d => console.log(d.replace('@campforge/', '')));
  ")

  for dep in $DEPS; do
    pkg_dir="$REPO_ROOT/packages/$dep"
    if [ -d "$pkg_dir" ] && [ -f "$pkg_dir/package.json" ]; then
      if tgz=$(cd "$pkg_dir" && npm pack --pack-destination "$OUT" 2>&1); then
        echo "  $dep -> $tgz"
      else
        echo "  $dep -> [error] npm pack failed:"
        echo "    $tgz"
      fi
    else
      echo "  $dep -> [skip] package directory not found"
    fi
  done
else
  echo "=== Packing all skill packages ==="
  for pkg_dir in "$REPO_ROOT/packages"/*/; do
    [ -f "$pkg_dir/package.json" ] || continue
    pkg_name=$(basename "$pkg_dir")
    if tgz=$(cd "$pkg_dir" && npm pack --pack-destination "$OUT" 2>&1); then
      echo "  $pkg_name -> $tgz"
    else
      echo "  $pkg_name -> [error] npm pack failed:"
      echo "    $tgz"
    fi
  done
fi

# Pack camp identity/knowledge tarball when --camp is specified
if [ -n "$CAMP" ]; then
  CAMP_FILES=()
  for pattern in identity knowledge tests scripts manifest.yaml; do
    target="$CAMP_DIR/$pattern"
    [ -e "$target" ] && CAMP_FILES+=("$pattern")
  done
  if [ ${#CAMP_FILES[@]} -gt 0 ]; then
    CAMP_TGZ="camp-${CAMP}.tgz"
    tar -czf "$OUT/$CAMP_TGZ" -C "$CAMP_DIR" "${CAMP_FILES[@]}"
    echo "  camp files -> $CAMP_TGZ (${CAMP_FILES[*]})"
  else
    echo "  [skip] no camp files (identity/knowledge/manifest.yaml/tests) found"
  fi
fi

# Include shared install helper so camp installers can fetch it from the same release
cp "$REPO_ROOT/scripts/install-common.sh" "$OUT/install-common.sh"
echo "  install-common.sh -> $OUT/install-common.sh"

count=$(find "$OUT" -name '*.tgz' 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "=== $count tarballs + install-common.sh ready in $OUT ==="
echo ""
if [ -n "$CAMP" ]; then
  echo "To release:"
  echo "  gh release create $CAMP-v<version> $OUT/*.tgz $OUT/install-common.sh"
else
  echo "To release per-camp (recommended):"
  echo "  ./scripts/release-pack.sh --camp <camp-name>"
  echo ""
  echo "To release all at once (legacy):"
  echo "  gh release create v<version> $OUT/*.tgz $OUT/install-common.sh"
fi
