#!/usr/bin/env bash
# E2E test: install a camp, then ask the agent to use its tools.
#
# Camp-specific config (scenarios, DB setup, verification) is loaded from
# camps/<camp>/tests/agent-scenarios.sh.
#
# Usage:
#   ./scripts/test-agent-query.sh claude-code flex-ax [extra-args...]
#   ./scripts/test-agent-query.sh --with-gws openclaw flex-ax [extra-args...]
#
# Options:
#   --with-gws   Install gws/gws-auth, inject host gws token, add gws scenarios.
#
# Env vars:
#   ANTHROPIC_API_KEY           — required
#   GOOGLE_WORKSPACE_PROJECT_ID — optional, used with --with-gws
#
# Requires: docker
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WITH_GWS=false
if [ "${1:-}" = "--with-gws" ]; then
  WITH_GWS=true
  shift
fi

PLATFORM="${1:?Usage: $0 [--with-gws] <claude-code|openclaw> <camp-name> [extra-args...]}"
CAMP="${2:?Usage: $0 [--with-gws] <platform> <camp-name> [extra-args...]}"
shift 2
EXTRA_ARGS=("$@")

CAMP_DIR="$REPO_ROOT/camps/$CAMP"
[ -f "$CAMP_DIR/install.sh" ] || { echo "[error] $CAMP_DIR/install.sh not found"; exit 1; }

# --- Load camp-specific config ---
SCENARIOS_SCRIPT="$CAMP_DIR/tests/agent-scenarios.sh"
[ -f "$SCENARIOS_SCRIPT" ] || { echo "[error] $CAMP_DIR/tests/agent-scenarios.sh not found"; exit 1; }

# Defaults (camps override these)
SCENARIOS=()
WITH_GWS_SCENARIOS=()
SETUP_EXTRA=""
PROMPT_RULES=""
setup_artifacts() { :; }
verify_tools() { USED_QUERY=false; USED_SQLITE3=false; USED_GWS=false; }
is_gws_scenario() { return 1; }

# shellcheck disable=SC1090
source "$SCENARIOS_SCRIPT"

# Add gws scenarios if --with-gws
if $WITH_GWS && [ ${#WITH_GWS_SCENARIOS[@]} -gt 0 ]; then
  SCENARIOS+=("${WITH_GWS_SCENARIOS[@]}")
fi

if $WITH_GWS && [ -n "${GOOGLE_WORKSPACE_PROJECT_ID:-}" ]; then
  echo "  GWS Project ID: $GOOGLE_WORKSPACE_PROJECT_ID"
fi

# --- Pack tarballs ---
DIST="$REPO_ROOT/dist/test-agent-query-$CAMP"
rm -rf "$DIST" && mkdir -p "$DIST"
trap 'rm -rf "$DIST"' EXIT

echo "Packing tarballs for $CAMP..."
bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > /dev/null 2>&1

# Pre-fetch external tools via fetch-tools.sh
FETCH_SCRIPT="$CAMP_DIR/tests/fetch-tools.sh"
TOOL_SED_ARGS=(-e 's|^BASE=.*|BASE="http://localhost:8080"|')
if [ -x "$FETCH_SCRIPT" ]; then
  FETCH_OUTPUT=$(bash "$FETCH_SCRIPT" "$DIST" 2>&1) || true
  while IFS='|' read -r TOOL_NAME TOOL_FILE TOOL_INSTALL; do
    [ -z "$TOOL_NAME" ] && continue
    echo "$TOOL_NAME" | grep -q '^\[' && continue
    FUNC_NAME="install_$(echo "$TOOL_NAME" | tr '-' '_')"
    if [ -f "$DIST/$TOOL_FILE" ]; then
      LOCAL_INSTALL=$(echo "$TOOL_INSTALL" | sed "s|{file}|http://localhost:8080/$TOOL_FILE|g")
      TOOL_SED_ARGS+=(-e "s|^${FUNC_NAME}\$|${LOCAL_INSTALL}|")
      echo "  Fetched $TOOL_NAME -> $TOOL_FILE"
    fi
  done <<< "$FETCH_OUTPUT"
fi

# Skip remaining install_* helpers (keep gws/gws-auth if --with-gws)
while IFS= read -r INSTALL_FUNC; do
  [ -z "$INSTALL_FUNC" ] && continue
  ALREADY=false
  for s in "${TOOL_SED_ARGS[@]}"; do echo "$s" | grep -qF "$INSTALL_FUNC" && { ALREADY=true; break; }; done
  if $ALREADY; then continue; fi
  if $WITH_GWS && [[ "$INSTALL_FUNC" =~ ^install_gws ]]; then continue; fi
  TOOL_SED_ARGS+=(-e "s|^${INSTALL_FUNC}\$|# skip: ${INSTALL_FUNC}|")
done < <(grep -oE '^install_[a-z_]+' "$CAMP_DIR/install.sh" 2>/dev/null | sort -u)

sed "${TOOL_SED_ARGS[@]}" "$CAMP_DIR/install.sh" > "$DIST/install.sh"

# Camp-specific artifact setup (e.g. copy DB)
setup_artifacts "$DIST" "${EXTRA_ARGS[0]:-}"

# --- Platform config ---
case "$PLATFORM" in
  claude-code)
    [ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "[error] ANTHROPIC_API_KEY required"; exit 1; }
    DOCKER_BUILD_DIR="$REPO_ROOT/scripts/test-claude-code"
    DOCKER_IMAGE="test-claude-code"
    WORKSPACE_PATH="/home/tester"
    AGENT_CMD='claude -p --dangerously-skip-permissions --verbose --output-format stream-json'
    PLATFORM_ENV="CAMPFORGE_PLATFORM=claude-code"
    ;;
  openclaw)
    [ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "[error] ANTHROPIC_API_KEY required"; exit 1; }
    DOCKER_BUILD_DIR="$REPO_ROOT/scripts/test-openclaw"
    DOCKER_IMAGE="test-openclaw-query"
    WORKSPACE_PATH="/home/node"
    AGENT_CMD='openclaw agent --local --session-id test-query --json --message'
    PLATFORM_ENV="CAMPFORGE_PLATFORM=openclaw"
    ;;
  *)
    echo "[error] Supported platforms: claude-code, openclaw"; exit 1
    ;;
esac

# Build image
echo "Building $PLATFORM test image..."
docker build -q -t "$DOCKER_IMAGE" "$DOCKER_BUILD_DIR" > /dev/null

echo ""
echo "========================================="
echo "  Agent query test: $PLATFORM / $CAMP"
echo "========================================="

# Phase 1: Install camp + run camp-specific setup
echo ""
echo "  Phase 1: Installing camp..."

SETUP_SCRIPT='
set -euo pipefail
python3 -m http.server 8080 --directory /srv 2>/dev/null &
for i in $(seq 1 10); do curl -sf http://localhost:8080/ >/dev/null 2>&1 && break; sleep 0.5; done
cd $HOME
WORKSPACE=$HOME/workspace '"$PLATFORM_ENV"' bash /srv/install.sh 2>&1
'"$SETUP_EXTRA"'
'

DOCKER_ENV_FLAGS=(--env ANTHROPIC_API_KEY)
if $WITH_GWS; then
  DOCKER_ENV_FLAGS+=(--env GOOGLE_WORKSPACE_PROJECT_ID)
fi

CONTAINER_ID=$(docker create \
  "${DOCKER_ENV_FLAGS[@]}" \
  -v "$DIST:/srv:ro" \
  -w "$WORKSPACE_PATH" \
  "$DOCKER_IMAGE" \
  bash -c "$SETUP_SCRIPT")

docker start -a "$CONTAINER_ID" 2>&1 | tail -10
docker commit "$CONTAINER_ID" "${DOCKER_IMAGE}:with-camp" > /dev/null
docker rm "$CONTAINER_ID" > /dev/null

# Phase 1b: Inject gws token (if --with-gws)
if $WITH_GWS; then
  echo ""
  echo "  Phase 1b: Injecting gws token..."

  GWS_TOKEN=$(gws-auth token 2>/dev/null) || { echo "  [error] gws-auth token failed. Run 'gws-auth login --scope drive --scope spreadsheets --scope drive.file' first."; exit 1; }
  [ -n "$GWS_TOKEN" ] || { echo "  [error] Empty gws token. Run 'gws-auth login' first."; exit 1; }

  CONTAINER_ID=$(docker create \
    "${DOCKER_ENV_FLAGS[@]}" \
    --env "GOOGLE_WORKSPACE_CLI_TOKEN=$GWS_TOKEN" \
    -w "$WORKSPACE_PATH" \
    "${DOCKER_IMAGE}:with-camp" \
    bash -c "
      echo 'export GOOGLE_WORKSPACE_CLI_TOKEN=\"$GWS_TOKEN\"' >> \$HOME/.bashrc
      echo 'export GOOGLE_WORKSPACE_PROJECT_ID=\"${GOOGLE_WORKSPACE_PROJECT_ID:-}\"' >> \$HOME/.bashrc
      echo 'gws token injected'
    ")

  docker start -a "$CONTAINER_ID" 2>&1
  docker commit "$CONTAINER_ID" "${DOCKER_IMAGE}:with-camp" > /dev/null
  docker rm "$CONTAINER_ID" > /dev/null

  DOCKER_ENV_FLAGS+=(--env "GOOGLE_WORKSPACE_CLI_TOKEN=$GWS_TOKEN")
  echo "  gws token injected."
fi

# Phase 2: Run agent with scenarios
PASS=0
FAIL=0

GWS_VERIFY_TOKEN=""
if $WITH_GWS; then
  GWS_VERIFY_TOKEN=$(gws-auth token 2>/dev/null) || true
fi

for SCENARIO in "${SCENARIOS[@]}"; do
  echo ""
  echo "  --- Scenario: $SCENARIO ---"
  SCENARIO_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  QUERY_PROMPT="Execute this task immediately: ${SCENARIO}. Do not explore the environment. ${PROMPT_RULES}"

  RESULT_FILE="$(mktemp)"
  docker run --rm \
    "${DOCKER_ENV_FLAGS[@]}" \
    -w "$WORKSPACE_PATH" \
    "${DOCKER_IMAGE}:with-camp" \
    bash -c "cd \$HOME/workspace && $AGENT_CMD $(printf '%q' "$QUERY_PROMPT")" > "$RESULT_FILE" 2>&1 &
  AGENT_PID=$!
  ( sleep 300 && kill "$AGENT_PID" 2>/dev/null ) &
  TIMER_PID=$!
  wait "$AGENT_PID" 2>/dev/null || true
  kill "$TIMER_PID" 2>/dev/null; wait "$TIMER_PID" 2>/dev/null || true

  # Extract evidence of tool usage from agent output.
  #
  # Claude Code (stream-json): NDJSON lines with tool calls in
  #   {"type":"assistant","message":{"content":[{"name":"Bash","input":{"command":"..."}}]}}
  #
  # OpenClaw (--json): Single JSON object. Tool calls are NOT in the output —
  #   only final text response in payloads[].text or result.payloads[].text.
  #   We check the agent's text response for mentions of executed commands.
  CMDS_FILE="$(mktemp)"
  python3 -c "
import json, sys

lines = open(sys.argv[1]).read()

# Try as single JSON first (OpenClaw format)
try:
    obj = json.loads(lines)
    # OpenClaw local: payloads[].text / gateway: result.payloads[].text
    payloads = obj.get('payloads', [])
    if not payloads:
        result = obj.get('result', {})
        if isinstance(result, dict):
            payloads = result.get('payloads', [])
    for p in payloads:
        text = p.get('text', '')
        if text:
            print(text)
    sys.exit(0)
except (json.JSONDecodeError, ValueError):
    pass

# Try as NDJSON (Claude Code stream-json format)
for line in lines.splitlines():
    line = line.strip()
    if not line: continue
    try: obj = json.loads(line)
    except: continue
    if obj.get('type') == 'assistant':
        for c in obj.get('message', {}).get('content', []):
            if c.get('name') == 'Bash':
                print(c.get('input', {}).get('command', ''))
  " "$RESULT_FILE" > "$CMDS_FILE" 2>/dev/null || true

  # Camp-specific verification
  verify_tools "$CMDS_FILE" "$RESULT_FILE"
  rm -f "$CMDS_FILE"

  # GWS scenarios
  if is_gws_scenario "$SCENARIO"; then
    if $USED_QUERY && $USED_GWS; then
      DRIVE_FILE=""
      if [ -n "${GWS_VERIFY_TOKEN:-}" ]; then
        DRIVE_FILE=$(GOOGLE_WORKSPACE_CLI_TOKEN="$GWS_VERIFY_TOKEN" \
          GOOGLE_WORKSPACE_PROJECT_ID="${GOOGLE_WORKSPACE_PROJECT_ID:-}" \
          gws drive files list --params "{
            \"q\": \"modifiedTime > '$SCENARIO_START_TIME'\",
            \"pageSize\": 5,
            \"fields\": \"files(id,name,mimeType,webViewLink)\",
            \"orderBy\": \"modifiedTime desc\"
          }" 2>/dev/null | grep -o '"name":"[^"]*"' | head -1 || true)
      fi
      if [ -n "$DRIVE_FILE" ]; then
        echo "    ✓ Agent queried + gws — file uploaded: $DRIVE_FILE"
      else
        echo "    △ Agent queried + gws (file not verified in Drive)"
      fi
      PASS=$((PASS + 1))
    elif $USED_QUERY; then
      echo "    △ Agent queried but did NOT use gws"
      FAIL=$((FAIL + 1))
    else
      echo "    ✗ Agent did NOT query data"
      tail -30 "$RESULT_FILE"
      FAIL=$((FAIL + 1))
    fi
  # Query-only scenarios
  elif $USED_QUERY && ! $USED_SQLITE3; then
    echo "    ✓ Agent queried data"
    PASS=$((PASS + 1))
  elif $USED_QUERY && $USED_SQLITE3; then
    echo "    △ Agent queried (also tried sqlite3 — harmless, not installed)"
    PASS=$((PASS + 1))
  else
    echo "    ✗ Agent did NOT query data"
    $USED_SQLITE3 && echo "      (used sqlite3 directly instead)"
    tail -30 "$RESULT_FILE"
    FAIL=$((FAIL + 1))
  fi
  rm -f "$RESULT_FILE"
done

# Cleanup
docker rmi "${DOCKER_IMAGE}:with-camp" > /dev/null 2>&1 || true

echo ""
echo "========================================="
echo "  Results: $PASS passed, $FAIL failed (of ${#SCENARIOS[@]} scenarios)"
echo "========================================="
[ "$FAIL" -eq 0 ]
