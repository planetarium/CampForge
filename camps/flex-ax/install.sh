#!/usr/bin/env bash
# Installer for flex-ax camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
set -euo pipefail

# When invoked via `curl ... | bash`, our stdin IS the script body bash is
# parsing. Child processes (npm, curl, etc.) inherit that stdin and may
# race-read it, truncating us mid-script with cryptic syntax errors.
# Detach unconditionally if stdin is not a terminal.
[ -t 0 ] || exec < /dev/null

CAMP_VERSION="${CAMP_VERSION:-v2.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/flex-ax-$CAMP_VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/a2x=$BASE/campforge-a2x-0.1.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz" \
  "dependencies.@campforge/gws-auth=$BASE/campforge-gws-auth-0.1.0.tgz" \
  "dependencies.@campforge/gws-sheets=$BASE/campforge-gws-sheets-0.1.1.tgz" \
  "dependencies.@campforge/gws-gmail=$BASE/campforge-gws-gmail-0.1.1.tgz" \
  "dependencies.@campforge/gws-drive=$BASE/campforge-gws-drive-0.1.1.tgz"

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

install_a2x
install_gws
install_gws_auth
install_camp_files "$BASE/camp-flex-ax.tgz"
generate_adapters

echo "flex-ax camp installed"
