#!/usr/bin/env bash
# Camp-specific config for test-agent-query.sh
# Sourced by the orchestrator — sets variables, not executed standalone.
#
# Required exports:
#   SCENARIOS     — array of test prompts
#   SETUP_EXTRA   — bash commands run after camp install (DB placement, wrappers, etc.)
#   PROMPT_RULES  — appended to each scenario prompt
#   verify_tools  — function: check $CMDS_FILE and $RESULT_FILE, set USED_* vars
#   is_gws_scenario — function: return 0 if scenario needs gws verification

# --- Artifacts ---
# Copy DB file into dist if provided
setup_artifacts() {
  local dist="$1" db_path="$2"
  if [ -n "$db_path" ] && [ -f "$db_path" ]; then
    cp "$db_path" "$dist/camp-data.db"
    echo "  DB: $(du -h "$db_path" | cut -f1) -> dist/camp-data.db"
  fi
}

# --- Post-install setup (runs inside Docker after camp install) ---
SETUP_EXTRA='
if [ -f /srv/camp-data.db ]; then
  # Place DB outside workspace so agent cannot discover it via ls/find.
  # flex-ax looks for output/flex-ax.db relative to CWD, so we create
  # a wrapper that cd to the DB location before running flex-ax.
  mkdir -p $HOME/.flex-ax-data/output
  cp /srv/camp-data.db $HOME/.flex-ax-data/output/flex-ax.db
  REAL_FLEX_AX=$(which flex-ax)
  cat > $HOME/.local/bin/flex-ax <<WRAPPER
#!/bin/bash
cd $HOME/.flex-ax-data
exec "$REAL_FLEX_AX" "\$@"
WRAPPER
  chmod +x $HOME/.local/bin/flex-ax
  echo "DB placed at ~/.flex-ax-data/ (hidden from workspace)"
fi
'

# --- Scenarios ---
SCENARIOS=(
  "Show the list of employees"
  "Show recent approval documents"
  "Show approval line status for each document"
)

WITH_GWS_SCENARIOS=(
  "Query expense data, export as CSV, and upload to Google Drive"
)

# --- Prompt rules ---
PROMPT_RULES="Use flex-ax query for data. Refer to skill docs in .agents/skills/ for tool usage."

# --- Verification ---
# cmds_file contains:
#   Claude Code: actual Bash commands extracted from stream-json tool_use
#   OpenClaw: agent's final text response (tool calls not in JSON output)
# Both are checked for evidence of tool usage.
verify_tools() {
  local cmds_file="$1" result_file="$2"
  USED_QUERY=false
  USED_SQLITE3=false
  USED_GWS=false
  grep -qiE 'flex-ax query' "$cmds_file" && USED_QUERY=true
  grep -qiE 'sqlite3' "$cmds_file" && USED_SQLITE3=true
  grep -qiE 'gws drive|gws sheets|uploaded.*drive|upload.*csv|drive.google.com' "$cmds_file" && USED_GWS=true
  # Fallback: check raw log for Drive upload evidence (file ID pattern)
  if ! $USED_GWS; then
    grep -qE 'drive.google.com|"webViewLink"' "$result_file" && USED_GWS=true
  fi
}

is_gws_scenario() {
  echo "$1" | grep -qiE 'Drive|Sheets|Gmail|mail'
}
