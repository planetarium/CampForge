#!/usr/bin/env bash
# E2E test: ask the agent to crawl flex data from scratch.
#
# The agent starts with NO DB and must:
#   1. Run flex-ax crawl (credentials mode)
#   2. Run flex-ax import
#   3. Query the resulting data
#
# Usage:
#   FLEX_EMAIL=... FLEX_PASSWORD=... \
#   ANTHROPIC_API_KEY=... \
#   ./scripts/test-agent-crawl.sh
#
# Requires: docker
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMP="flex-ax"
CAMP_DIR="$REPO_ROOT/camps/$CAMP"

[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "[error] ANTHROPIC_API_KEY required"; exit 1; }
[ -n "${FLEX_EMAIL:-}" ] || { echo "[error] FLEX_EMAIL required"; exit 1; }
[ -n "${FLEX_PASSWORD:-}" ] || { echo "[error] FLEX_PASSWORD required"; exit 1; }

# --- Pack tarballs ---
DIST="$REPO_ROOT/dist/test-agent-crawl"
rm -rf "$DIST" && mkdir -p "$DIST"
trap 'rm -rf "$DIST"' EXIT

echo "Packing tarballs..."
bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > /dev/null 2>&1

# Pre-fetch flex-ax CLI
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

while IFS= read -r INSTALL_FUNC; do
  [ -z "$INSTALL_FUNC" ] && continue
  ALREADY=false
  for s in "${TOOL_SED_ARGS[@]}"; do echo "$s" | grep -qF "$INSTALL_FUNC" && { ALREADY=true; break; }; done
  $ALREADY || TOOL_SED_ARGS+=(-e "s|^${INSTALL_FUNC}\$|# skip: ${INSTALL_FUNC}|")
done < <(grep -oE '^install_[a-z_]+' "$CAMP_DIR/install.sh" 2>/dev/null | sort -u)

sed "${TOOL_SED_ARGS[@]}" "$CAMP_DIR/install.sh" > "$DIST/install.sh"

# --- Build image ---
DOCKER_IMAGE="test-claude-code"
echo "Building test image..."
docker build -q -t "$DOCKER_IMAGE" "$REPO_ROOT/scripts/test-claude-code" > /dev/null

echo ""
echo "========================================="
echo "  Agent crawl test: flex-ax"
echo "========================================="

# Phase 1: Install camp (no DB)
echo ""
echo "  Phase 1: Installing camp (no DB)..."

SETUP_SCRIPT='
set -euo pipefail
python3 -m http.server 8080 --directory /srv 2>/dev/null &
for i in $(seq 1 10); do curl -sf http://localhost:8080/ >/dev/null 2>&1 && break; sleep 0.5; done
cd $HOME
WORKSPACE=$HOME/workspace bash /srv/install.sh 2>&1

# Create .env for flex-ax credentials auth
REAL_FLEX_AX=$(which flex-ax)
mkdir -p $HOME/.flex-ax-data
cat > $HOME/.flex-ax-data/.env <<ENVFILE
AUTH_MODE=credentials
FLEX_EMAIL='"$FLEX_EMAIL"'
FLEX_PASSWORD='"$FLEX_PASSWORD"'
ENVFILE

# Wrapper: flex-ax runs from .flex-ax-data dir (picks up .env and writes output/ there)
cat > $HOME/.local/bin/flex-ax <<WRAPPER
#!/bin/bash
cd $HOME/.flex-ax-data
exec "$REAL_FLEX_AX" "\$@"
WRAPPER
chmod +x $HOME/.local/bin/flex-ax
echo "flex-ax configured with credentials auth"
'

CONTAINER_ID=$(docker create \
  --env ANTHROPIC_API_KEY \
  --env FLEX_EMAIL \
  --env FLEX_PASSWORD \
  -v "$DIST:/srv:ro" \
  -w /home/tester \
  "$DOCKER_IMAGE" \
  bash -c "$SETUP_SCRIPT")

docker start -a "$CONTAINER_ID" 2>&1 | tail -5
docker commit "$CONTAINER_ID" "${DOCKER_IMAGE}:crawl-test" > /dev/null
docker rm "$CONTAINER_ID" > /dev/null

# Phase 2: Ask agent to crawl + query
echo ""
echo "  Phase 2: Agent crawl + query..."

CRAWL_PROMPT="너는 flex-ax 캠프가 설치된 환경에 있어. workspace 디렉토리에서 작업해.

데이터가 아직 없으니 다음을 순서대로 해줘:
1. flex-ax crawl 을 실행해서 flex 데이터를 크롤링해
2. flex-ax import 를 실행해서 데이터를 변환해
3. flex-ax query 로 사용자 목록을 조회해서 보여줘

규칙:
- 반드시 flex-ax CLI만 사용해. sqlite3 등으로 직접 접근하지 마.
- 크롤링은 시간이 걸릴 수 있으니 기다려."

RESULT_FILE="$(mktemp)"
docker run --rm \
  --env ANTHROPIC_API_KEY \
  -w /home/tester/workspace \
  "${DOCKER_IMAGE}:crawl-test" \
  bash -c "cd \$HOME/workspace && claude -p --dangerously-skip-permissions --verbose --output-format stream-json $(printf '%q' "$CRAWL_PROMPT")" > "$RESULT_FILE" 2>&1 || true

# Verify results
CRAWL_OK=false
IMPORT_OK=false
QUERY_OK=false

grep -qE '"command".*flex-ax.*crawl|flex-ax crawl' "$RESULT_FILE" && CRAWL_OK=true
grep -qE '"command".*flex-ax.*import|flex-ax import' "$RESULT_FILE" && IMPORT_OK=true
grep -qE '"command".*flex-ax.*query|flex-ax query' "$RESULT_FILE" && QUERY_OK=true

echo ""
echo "  Results:"
$CRAWL_OK && echo "    ✓ flex-ax crawl executed" || echo "    ✗ flex-ax crawl NOT executed"
$IMPORT_OK && echo "    ✓ flex-ax import executed" || echo "    ✗ flex-ax import NOT executed"
$QUERY_OK && echo "    ✓ flex-ax query executed" || echo "    ✗ flex-ax query NOT executed"

rm -f "$RESULT_FILE"
docker rmi "${DOCKER_IMAGE}:crawl-test" > /dev/null 2>&1 || true

echo ""
if $CRAWL_OK && $IMPORT_OK && $QUERY_OK; then
  echo "========================================="; echo "  PASS: crawl → import → query pipeline"; echo "========================================="
else
  echo "========================================="; echo "  FAIL: pipeline incomplete"; echo "========================================="
  exit 1
fi
