#!/usr/bin/env bash
# Camp-specific config for test-agent-query.sh
# Sourced by the orchestrator — sets variables, not executed standalone.
#
# Required exports:
#   SCENARIOS     — array of test prompts
#   SETUP_EXTRA   — bash commands run after camp install
#   PROMPT_RULES  — appended to each scenario prompt
#   verify_tools  — function: check $CMDS_FILE and $RESULT_FILE, set USED_* vars
#   is_gws_scenario — function: return 0 if scenario needs gws verification

# --- Artifacts ---
# This camp talks to a remote A2A agent; nothing to stage on the host.
setup_artifacts() {
  :
}

# --- Post-install setup (runs inside Docker after camp install) ---
# The agent is reached via $FLEX_HR_AGENT_URL; no local fixture is required.
SETUP_EXTRA=''

# --- Scenarios ---
SCENARIOS=(
  "Show the list of users"
  "Show recent approval documents"
  "Show approval line status for each document"
)

WITH_GWS_SCENARIOS=(
  "Query expense data, export as CSV, and upload to Google Drive"
)

# --- Prompt rules ---
PROMPT_RULES="Use 'gq \"\$FLEX_HR_GQL\" -H \"Authorization: Bearer \$FLEX_HR_TOKEN\" ...' for HR data queries. Use a2x only for the initial device-flow auth that mints the token. Refer to skill docs in .agents/skills/ for tool usage."

# --- Verification ---
verify_tools() {
  local cmds_file="$1" result_file="$2"
  USED_GQL=false
  USED_DIRECT_DB=false
  USED_A2X_SEND=false
  USED_GWS=false
  grep -qE 'gq +"?\$?FLEX_HR_GQL' "$cmds_file" && USED_GQL=true
  grep -qE 'sqlite3|flex-ax query' "$cmds_file" && USED_DIRECT_DB=true
  grep -qE 'a2x a2a (send|stream) ' "$cmds_file" && USED_A2X_SEND=true
  grep -qE 'gws drive|gws sheets' "$cmds_file" && USED_GWS=true
  # Fallback: check raw log for Drive upload evidence
  if ! $USED_GWS; then
    grep -qE '"id":.*"1[A-Za-z0-9_-]' "$result_file" && grep -qE 'drive.google.com\|upload\|Upload' "$result_file" && USED_GWS=true
  fi
}

is_gws_scenario() {
  echo "$1" | grep -qiE 'Drive|Sheets|Gmail|mail'
}
