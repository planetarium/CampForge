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
# This camp uses local flex-ax exports; no extra fixture is staged here.
setup_artifacts() {
  :
}

# --- Post-install setup (runs inside Docker after camp install) ---
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
PROMPT_RULES="Use 'flex-ax query \"SQL\"' for HR data queries. If data is missing or stale, check 'flex-ax status' and then use 'flex-ax crawl' plus 'flex-ax import'. Do not use sqlite3 or read DB files directly. Refer to skill docs in .agents/skills/ for tool usage."

# --- Verification ---
# Contract with scripts/test-agent-query.sh: must export USED_QUERY,
# USED_SQLITE3, USED_GWS. We map:
#   USED_QUERY   ← the agent issued a flex-ax SQL query (correct path)
#   USED_SQLITE3 ← the agent fell back to sqlite3 / direct DB access (forbidden)
#   USED_GWS     ← Google Workspace upload/Sheets evidence
verify_tools() {
  local cmds_file="$1" result_file="$2"
  USED_QUERY=false
  USED_SQLITE3=false
  USED_GWS=false
  grep -qE 'flex-ax +query +["'\'']' "$cmds_file" && USED_QUERY=true
  if grep -qE 'sqlite3|python3? .*(sqlite|\\.db)|\\.db\\b' "$cmds_file"; then
    USED_SQLITE3=true
    USED_QUERY=false
  fi
  grep -qE 'gws drive|gws sheets' "$cmds_file" && USED_GWS=true
  # Fallback: check raw log for Drive upload evidence
  if ! $USED_GWS; then
    grep -qE '"id":.*"1[A-Za-z0-9_-]' "$result_file" && grep -qE 'drive.google.com\|upload\|Upload' "$result_file" && USED_GWS=true
  fi
}

is_gws_scenario() {
  echo "$1" | grep -qiE 'Drive|Sheets|Gmail|mail'
}
