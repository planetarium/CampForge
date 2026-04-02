#!/usr/bin/env bash
# Installer for 9c-backoffice camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/9c-backoffice/install.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.1}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/9c-backoffice=$BASE/campforge-9c-backoffice-1.0.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz"

npx skillpm install

echo "9c-backoffice camp installed"
