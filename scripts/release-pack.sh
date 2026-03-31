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
  pkg_name=$(basename "$pkg_dir")
  (cd "$pkg_dir" && npm pack --pack-destination "$OUT" 2>/dev/null)
  echo "  $pkg_name -> $(ls -1 "$OUT"/*"$pkg_name"* 2>/dev/null | tail -1 | xargs basename)"
done

echo ""
echo "=== $(ls "$OUT"/*.tgz 2>/dev/null | wc -l | tr -d ' ') tarballs ready in $OUT ==="
echo ""
echo "To release:"
echo "  gh release create v1.0.0 $OUT/*.tgz"
