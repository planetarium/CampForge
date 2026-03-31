#!/usr/bin/env bash
# Remote installer for iap-manager camp
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/iap-manager/install-remote.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

cd "${WORKSPACE:-workspace}"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/iap-product-query=$BASE/campforge-iap-product-query-1.0.0.tgz" \
  "dependencies.@campforge/iap-product-import=$BASE/campforge-iap-product-import-1.0.0.tgz" \
  "dependencies.@campforge/iap-receipt-query=$BASE/campforge-iap-receipt-query-1.0.0.tgz" \
  "dependencies.@campforge/iap-asset-import=$BASE/campforge-iap-asset-import-1.0.0.tgz" \
  "dependencies.@campforge/iap-image-upload=$BASE/campforge-iap-image-upload-1.0.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz"

npx skillpm install

echo "iap-manager camp installed (via skillpm + release tarball)"
