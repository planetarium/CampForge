#!/usr/bin/env bash
# Installer for flex-ax camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
set -euo pipefail

CAMP_VERSION="${CAMP_VERSION:-v1.1.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/flex-ax-$CAMP_VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/flex-query=$BASE/campforge-flex-query-0.1.0.tgz" \
  "dependencies.@campforge/flex-crawl=$BASE/campforge-flex-crawl-0.1.0.tgz" \
  "dependencies.@campforge/gws-auth=$BASE/campforge-gws-auth-0.1.0.tgz" \
  "dependencies.@campforge/gws-sheets=$BASE/campforge-gws-sheets-0.1.0.tgz" \
  "dependencies.@campforge/gws-gmail=$BASE/campforge-gws-gmail-0.1.0.tgz" \
  "dependencies.@campforge/gws-drive=$BASE/campforge-gws-drive-0.1.0.tgz"

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

install_flex_ax
install_gws
install_gws_auth
install_camp_files "$BASE/camp-flex-ax.tgz"
generate_adapters

# Install freshness check script
FRESHNESS_SCRIPT="scripts/check-freshness.sh"
if [ -f "$FRESHNESS_SCRIPT" ]; then
  echo ":: Freshness check already exists"
elif [ -f "/srv/camp-flex-ax.tgz" ]; then
  # Extract from camp tarball (remote install)
  tar xzf "/srv/camp-flex-ax.tgz" "$FRESHNESS_SCRIPT" 2>/dev/null || true
fi

# Set up platform-specific data freshness hooks
PLATFORM="$(detect_platform)"
case "$PLATFORM" in
  claude-code)
    # UserPromptSubmit hook: check data freshness on each prompt
    CHECK_CMD="$(pwd)/scripts/check-freshness.sh"
    if [ -f ".claude/settings.json" ]; then
      echo "  [action-required] Add this hook to .claude/settings.json:"
    else
      cat > .claude/settings.json <<HOOKJSON
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "command": "bash $CHECK_CMD",
        "description": "Check flex-ax data freshness and crawl if stale"
      }
    ]
  }
}
HOOKJSON
      echo "  Created .claude/settings.json with freshness check hook"
    fi
    ;;
  openclaw)
    # BOOT.md: runs on gateway startup
    if [ ! -f "BOOT.md" ]; then
      cat > BOOT.md <<'BOOTMD'
Run this command to check if flex-ax data needs refreshing:

```bash
bash scripts/check-freshness.sh
```
BOOTMD
      echo "  Created BOOT.md with freshness check"
    else
      echo "  [action-required] Existing BOOT.md found. Add freshness check manually."
    fi
    ;;
esac

echo "flex-ax camp installed"
