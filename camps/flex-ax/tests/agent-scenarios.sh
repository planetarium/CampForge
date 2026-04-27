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
# Contract with scripts/test-agent-query.sh: must export USED_QUERY,
# USED_SQLITE3, USED_GWS. We map:
#   USED_QUERY   ← the agent issued a Flex HR GraphQL query via gq (correct path)
#   USED_SQLITE3 ← the agent fell back to local DB access (forbidden by camp rules)
#   USED_GWS     ← Google Workspace upload/Sheets evidence
verify_tools() {
  local cmds_file="$1" result_file="$2"
  USED_QUERY=false
  USED_SQLITE3=false
  USED_GWS=false
  # Accept either `gq $FLEX_HR_GQL ...` (the documented form) or
  # an inlined https://.../graphql URL (still a valid camp-rule path).
  grep -qE 'gq +("?(\$?FLEX_HR_GQL|https?://[^"[:space:]]*/graphql)"?)' "$cmds_file" && USED_QUERY=true
  # Local DB access is forbidden in this camp. If detected, force the
  # query-path check to fail even when the agent ALSO ran a valid `gq`
  # call — the orchestrator's pass condition is `USED_QUERY && !USED_SQLITE3`,
  # but the existing pass branches that just check `USED_QUERY` would
  # otherwise let a forbidden fallback slip through as a partial success.
  if grep -qE 'sqlite3|flex-ax query' "$cmds_file"; then
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
