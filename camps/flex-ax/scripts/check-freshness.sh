#!/usr/bin/env bash
# Check flex-ax data freshness and crawl if stale.
# Used by platform hooks (Claude Code UserPromptSubmit, OpenClaw BOOT.md, etc.)
#
# Environment:
#   FLEX_AX_MAX_AGE_SEC — max data age in seconds (default: 10800 = 3 hours)
#   FLEX_AX_AUTH_MODE   — crawl auth mode (default: credentials)
set -euo pipefail

MAX_AGE="${FLEX_AX_MAX_AGE_SEC:-10800}"

# Check if flex-ax is available
command -v flex-ax >/dev/null 2>&1 || exit 0

FRESHNESS=$(flex-ax query "SELECT value FROM crawl_meta WHERE key='crawled_at'" 2>/dev/null | python3 -c "
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
AUTH_FLAG=""
if [ -n "${FLEX_AX_AUTH_MODE:-}" ]; then
  AUTH_FLAG="--auth $FLEX_AX_AUTH_MODE"
fi

if flex-ax $AUTH_FLAG crawl 2>&1 && flex-ax import 2>&1; then
  echo "[flex-ax] Data refreshed."
else
  echo "[flex-ax] Crawl failed — working with existing data." >&2
fi
