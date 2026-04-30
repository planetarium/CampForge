#!/usr/bin/env bash
# Camp-specific config for test-agent-query.sh

setup_artifacts() {
  :
}

SETUP_EXTRA=''

SCENARIOS=(
  "Show the list of users"
  "Show recent approval documents"
  "Show approval line status for each document"
)

WITH_GWS_SCENARIOS=(
  "Query expense data, export as CSV, and upload to Google Drive"
)

PROMPT_RULES="Use 'gq \"\$FLEX_HR_GQL\" -H \"Authorization: Bearer \$FLEX_HR_TOKEN\" ...' for HR data queries. Use a2x only for the initial device-flow auth."

verify_tools() {
  local cmds_file="$1" result_file="$2"
  USED_QUERY=false
  USED_SQLITE3=false
  USED_GWS=false
  grep -qE 'gq +("?(\$?FLEX_HR_GQL|https?://[^"[:space:]]*/graphql)"?)' "$cmds_file" && USED_QUERY=true
  if grep -qE 'sqlite3|flex-ax query' "$cmds_file"; then
    USED_SQLITE3=true
    USED_QUERY=false
  fi
  grep -qE 'gws drive|gws sheets' "$cmds_file" && USED_GWS=true
  if ! $USED_GWS; then
    grep -qE '"id":.*"1[A-Za-z0-9_-]' "$result_file" && grep -qE 'drive.google.com\|upload\|Upload' "$result_file" && USED_GWS=true
  fi
}

is_gws_scenario() {
  echo "$1" | grep -qiE 'Drive|Sheets|Gmail|mail'
}
