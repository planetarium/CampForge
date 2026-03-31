#!/bin/bash
# Pack all skill packages into tarballs for GitHub Release
# Usage: ./scripts/release-pack.sh [output-dir]
#   Then: gh release create v1.0.0 dist/tarballs/*.tgz
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO_ROOT/dist/tarballs}"
mkdir -p "$OUT"

echo "=== Packing skill packages ==="
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

count=$(find "$OUT" -name '*.tgz' 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "=== $count tarballs ready in $OUT ==="
echo ""
echo "To release:"
echo "  gh release create v1.0.0 $OUT/*.tgz"
