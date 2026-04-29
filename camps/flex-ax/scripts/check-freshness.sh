#!/usr/bin/env bash
# Check flex-ax data freshness and crawl if stale.
# Used by platform hooks (Claude Code UserPromptSubmit, OpenClaw BOOT.md, etc.)
#
# Environment:
#   FLEX_AX_MAX_AGE_SEC — max data age in seconds (default: 10800 = 3 hours)
set -euo pipefail

MAX_AGE="${FLEX_AX_MAX_AGE_SEC:-10800}"

# Check if flex-ax is available
command -v flex-ax >/dev/null 2>&1 || exit 0

STATUS_OUTPUT="$(flex-ax status 2>/dev/null || true)"
if ! printf '%s\n' "$STATUS_OUTPUT" | grep -q 'password[[:space:]]*:[[:space:]]*set'; then
  echo "[flex-ax] Credentials are not configured. Run 'flex-ax login' first." >&2
  exit 0
fi

FRESHNESS=$(flex-ax query "SELECT value FROM crawl_meta WHERE key='last_crawled_at'" 2>/dev/null | python3 -c "
import json,sys,datetime
try:
    ts = json.load(sys.stdin)[0]['value']
    age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(ts)).total_seconds()
    print('fresh' if age < $MAX_AGE else 'stale')
except: print('missing')
" 2>/dev/null) || FRESHNESS="missing"

if [ "$FRESHNESS" = "fresh" ]; then
  exit 0
fi

echo "[flex-ax] Data is ${FRESHNESS} — crawling..."

if flex-ax crawl 2>&1 && flex-ax import 2>&1; then
  echo "[flex-ax] Data refreshed."
else
  echo "[flex-ax] Crawl failed — working with existing data." >&2
fi
