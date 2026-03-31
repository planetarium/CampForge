#!/usr/bin/env bash
# Remote installer for v8-admin camp
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/v8-admin/install-remote.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS"
cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/v8-admin=$BASE/campforge-v8-admin-1.0.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz" \
  "dependencies.@campforge/gws-sheets=$BASE/campforge-gws-sheets-0.1.0.tgz"

npx skillpm install

# Install gws + gws-auth
npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
  echo "  [warn] gws/gws-auth install failed. Install manually."

echo "v8-admin camp installed (via skillpm + release tarball)"
