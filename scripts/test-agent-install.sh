#!/usr/bin/env bash
# E2E test: tell each agent platform to install a camp by itself.
#
# The agent receives a single instruction and must:
#   1. Run the install script
#   2. Follow any [action-required] guides in the output
#   3. Report what skills were installed
#
# Usage:
#   ./scripts/test-agent-install.sh openclaw   v8-admin
#   ./scripts/test-agent-install.sh claude-code campforge-guide
#   ./scripts/test-agent-install.sh codex       9c-backoffice
#
# Env vars:
#   ANTHROPIC_API_KEY  — required for openclaw, claude-code
#   OPENAI_API_KEY     — required for codex (or CODEX_API_KEY)
#
# Requires: docker
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PLATFORM="${1:?Usage: $0 <openclaw|claude-code|codex> <camp-name>}"
CAMP="${2:?Usage: $0 <platform> <camp-name>}"

CAMP_DIR="$REPO_ROOT/camps/$CAMP"
[ -f "$CAMP_DIR/install.sh" ] || { echo "[error] $CAMP_DIR/install.sh not found"; exit 1; }

# --- Pack tarballs ---
DIST="$REPO_ROOT/dist/test-agent-$PLATFORM-$CAMP"
rm -rf "$DIST" && mkdir -p "$DIST"
echo "Packing tarballs for $CAMP..."
bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > /dev/null 2>&1
sed -e 's|^BASE=.*|BASE="http://localhost:8080"|' "$CAMP_DIR/install.sh" > "$DIST/install.sh"

# --- Platform-specific config ---
DOCKER_IMAGE=""
DOCKER_BUILD_DIR=""
AGENT_CMD=""
ENV_FLAGS=""
WORKSPACE_PATH=""

INSTALL_PROMPT="다음 작업을 순서대로 수행해줘:
1. 먼저 python3 -m http.server 8080 --directory /srv & 로 파일 서버를 백그라운드로 시작해
2. WORKSPACE=\$HOME/workspace bash /srv/install.sh 를 실행해서 ${CAMP} 캠프를 설치해
3. 설치 출력에 [action-required] 가이드가 있으면, 그 지시에 따라 설정을 적용해
4. 최종 결과를 알려줘"

case "$PLATFORM" in
  openclaw)
    [ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "[error] ANTHROPIC_API_KEY required"; exit 1; }
    DOCKER_BUILD_DIR="$REPO_ROOT/scripts/test-openclaw"
    DOCKER_IMAGE="test-openclaw-test-openclaw"
    WORKSPACE_PATH="/home/node"
    ENV_FLAGS="-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
    AGENT_CMD="openclaw agent --local --session-id test-install --json --message"
    ;;
  claude-code)
    [ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "[error] ANTHROPIC_API_KEY required"; exit 1; }
    DOCKER_BUILD_DIR="$REPO_ROOT/scripts/test-claude-code"
    DOCKER_IMAGE="test-claude-code"
    WORKSPACE_PATH="/home/tester"
    ENV_FLAGS="-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
    AGENT_CMD="claude -p --dangerously-skip-permissions --output-format json"
    ;;
  codex)
    CODEX_KEY="${CODEX_API_KEY:-${OPENAI_API_KEY:-}}"
    [ -n "$CODEX_KEY" ] || { echo "[error] OPENAI_API_KEY or CODEX_API_KEY required"; exit 1; }
    DOCKER_BUILD_DIR="$REPO_ROOT/scripts/test-codex"
    DOCKER_IMAGE="test-codex"
    WORKSPACE_PATH="/home/tester"
    ENV_FLAGS="-e CODEX_API_KEY=$CODEX_KEY"
    AGENT_CMD="codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --json"
    ;;
  *)
    echo "[error] Unknown platform: $PLATFORM (use openclaw, claude-code, or codex)"
    exit 1
    ;;
esac

# --- Build image ---
echo "Building $PLATFORM test image..."
docker build -q -t "$DOCKER_IMAGE" "$DOCKER_BUILD_DIR" > /dev/null

# --- Run agent ---
echo ""
echo "========================================="
echo "  Agent install test: $PLATFORM / $CAMP"
echo "========================================="
echo "  Telling the agent to install $CAMP..."
echo ""

DOCKER_EXTRA_FLAGS=""
if [ "$PLATFORM" = "codex" ]; then
  # Codex bwrap sandbox needs full privileges inside Docker
  DOCKER_EXTRA_FLAGS="--privileged"
fi

docker run --rm \
  $ENV_FLAGS \
  $DOCKER_EXTRA_FLAGS \
  -v "$DIST:/srv:ro" \
  -w "$WORKSPACE_PATH" \
  "$DOCKER_IMAGE" \
  bash -c "$AGENT_CMD $(printf '%q' "$INSTALL_PROMPT")" 2>&1

# --- Cleanup ---
rm -rf "$DIST"
