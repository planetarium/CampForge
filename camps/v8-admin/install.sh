#!/usr/bin/env bash
# Installer for v8-admin camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/v8-admin/install.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/v8-admin=$BASE/campforge-v8-admin-1.0.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz" \
  "dependencies.@campforge/gws-sheets=$BASE/campforge-gws-sheets-0.1.0.tgz"

npx skillpm install

# Install gws + gws-auth (required by gws-sheets skill)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
COMMON="$SCRIPT_DIR/../../scripts/install-common.sh"
if [ -f "$COMMON" ]; then
  # shellcheck disable=SC1090
  source "$COMMON"
else
  TMP_COMMON="$(mktemp)"
  curl -fsSL "$BASE/install-common.sh" -o "$TMP_COMMON"
  # shellcheck disable=SC1090
  source "$TMP_COMMON"
  rm -f "$TMP_COMMON"
fi
install_gws
install_gws_auth

echo "v8-admin camp installed"
