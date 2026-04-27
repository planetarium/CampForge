#!/usr/bin/env bash
# Installer for campforge-guide camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/campforge-guide/install.sh | bash
set -euo pipefail

CAMP_VERSION="${CAMP_VERSION:-v1.0.2}"
BASE="https://github.com/planetarium/CampForge/releases/download/campforge-guide-${CAMP_VERSION}"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/camp-create=$BASE/campforge-camp-create-0.1.0.tgz" \
  "dependencies.@campforge/camp-validate=$BASE/campforge-camp-validate-0.1.0.tgz" \
  "dependencies.@campforge/camp-add-skill=$BASE/campforge-camp-add-skill-0.1.0.tgz" \
  "dependencies.@campforge/camp-sync=$BASE/campforge-camp-sync-0.1.0.tgz" \
  "dependencies.@campforge/camp-bench=$BASE/campforge-camp-bench-0.1.0.tgz" \
  "dependencies.@campforge/campforge-interview=$BASE/campforge-campforge-interview-0.1.0.tgz"

npx skillpm install

# Source shared install helpers
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

install_camp_files "$BASE/camp-campforge-guide.tgz"
generate_adapters

echo "campforge-guide camp installed"
