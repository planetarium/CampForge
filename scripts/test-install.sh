#!/usr/bin/env bash
# E2E test: verify camp installers produce correct files and platform adapters.
#
# Usage:
#   ./scripts/test-install.sh              # Test all camps
#   ./scripts/test-install.sh v8-admin     # Test a specific camp
#
# Requires: docker
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMPS=("$@")
if [ ${#CAMPS[@]} -eq 0 ]; then
  CAMPS=(v8-admin 9c-backoffice campforge-guide)
fi

PASS=0
FAIL=0

# Run installer in Docker with the given platform and return output.
# Usage: run_installer <dist-dir> <platform> [preseed-script]
# preseed-script: optional bash commands run before the installer (e.g. to create existing files)
run_installer() {
  local dist="$1" platform="$2" preseed="${3:-}"
  docker run --rm \
    -v "$dist:/srv" \
    -e "CAMPFORGE_PLATFORM=$platform" \
    node:20 bash -c '
      set -euo pipefail
      python3 -m http.server 8080 --directory /srv 2>/dev/null &
      SERVER_PID=$!
      SERVER_READY=false
      for i in $(seq 1 10); do
        if curl -sf http://localhost:8080/ >/dev/null 2>&1; then
          SERVER_READY=true
          break
        fi
        sleep 0.5
      done
      if [ "$SERVER_READY" != "true" ]; then
        echo "[error] HTTP server failed to start" >&2
        exit 1
      fi
      cd /tmp
      # Pre-seed existing files if requested
      '"$preseed"'
      bash /srv/install.sh 2>&1
      echo "---INSTALLED_FILES---"
      find workspace -type f \( -name "*.md" -o -name "*.yaml" \) 2>/dev/null | sort
      echo "---SKILL_FILES---"
      find workspace -path "*/skills/*/SKILL.md" -type f 2>/dev/null | sort
      echo "---ADAPTER_CLAUDE_MD---"
      cat workspace/.claude/CLAUDE.md 2>/dev/null || echo "(not found)"
      echo "---ADAPTER_AGENTS_MD---"
      cat workspace/AGENTS.md 2>/dev/null || echo "(not found)"
      echo "---ADAPTER_AGENTS_MD_SIZE---"
      wc -c < workspace/AGENTS.md 2>/dev/null || echo "0"
      echo "---ADAPTER_IDENTITY_AGENTS_MD---"
      cat workspace/identity/AGENTS.md 2>/dev/null || echo "(not found)"
      echo "---ADAPTER_STAGING---"
      cat workspace/.campforge-context.md 2>/dev/null || echo "(not found)"
      echo "---ADAPTER_END---"
      kill $SERVER_PID 2>/dev/null
    ' 2>&1
}

for CAMP in "${CAMPS[@]}"; do
  echo ""
  echo "========================================="
  echo "  Testing camp: $CAMP"
  echo "========================================="

  CAMP_DIR="$REPO_ROOT/camps/$CAMP"
  [ -f "$CAMP_DIR/install.sh" ] || { echo "  [skip] no install.sh"; continue; }

  # 1. Pack tarballs
  DIST="$REPO_ROOT/dist/test-$CAMP"
  rm -rf "$DIST"
  mkdir -p "$DIST"
  PACK_LOG="$DIST/release-pack.log"
  if ! bash "$REPO_ROOT/scripts/release-pack.sh" --camp "$CAMP" "$DIST" > "$PACK_LOG" 2>&1; then
    echo "  [error] release-pack.sh failed for $CAMP"
    cat "$PACK_LOG"
    exit 1
  fi
  rm -f "$PACK_LOG"

  # 2. Build a test install script: replace BASE with local server URL
  #    and skip post-install binaries (gws/gws-auth) that aren't relevant
  sed \
    -e 's|^BASE=.*|BASE="http://localhost:8080"|' \
    -e 's|^install_gws$|# skip: install_gws|' \
    -e 's|^install_gws_auth$|# skip: install_gws_auth|' \
    "$CAMP_DIR/install.sh" > "$DIST/install.sh"

  # 3. Collect expected files
  HAS_IDENTITY=false
  EXPECTED_CAMP=()
  for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md knowledge/glossary.md manifest.yaml; do
    [ -f "$CAMP_DIR/$f" ] && EXPECTED_CAMP+=("$f")
  done
  [ -f "$CAMP_DIR/identity/SOUL.md" ] && HAS_IDENTITY=true

  EXPECTED_SKILLS=()
  SKILL_NAMES=$(node -e "
    const pkg = require('$CAMP_DIR/package.json');
    Object.keys(pkg.dependencies || {})
      .filter(d => d.startsWith('@campforge/'))
      .forEach(d => console.log(d.slice('@campforge/'.length)));
  ")
  for skill in $SKILL_NAMES; do
    EXPECTED_SKILLS+=("$skill")
  done

  # Collect identity/knowledge file paths for adapter checks
  IDENTITY_FILES=()
  for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md; do
    [ -f "$CAMP_DIR/$f" ] && IDENTITY_FILES+=("$f")
  done
  KNOWLEDGE_FILES=()
  for f in "$CAMP_DIR"/knowledge/*.md "$CAMP_DIR"/knowledge/decision-trees/*.md; do
    [ -f "$f" ] && KNOWLEDGE_FILES+=("${f#"$CAMP_DIR/"}")
  done

  # -------------------------------------------------------
  # Test each platform (clean install)
  # -------------------------------------------------------
  for PLATFORM in claude-code openclaw codex; do
    echo ""
    echo "  --- Platform: $PLATFORM ---"
    PLATFORM_PASS=true

    DOCKER_EXIT=0
    RESULT=$(run_installer "$DIST" "$PLATFORM") || DOCKER_EXIT=$?

    if [ "$DOCKER_EXIT" -ne 0 ]; then
      echo "    [error] Docker installer exited with code $DOCKER_EXIT"
      echo "$RESULT" | tail -20
      FAIL=$((FAIL + 1))
      continue
    fi

    # Common checks: camp files + skills (only for first platform to avoid noise)
    if [ "$PLATFORM" = "claude-code" ]; then
      echo "    Verifying camp files..."
      for f in "${EXPECTED_CAMP[@]}"; do
        if echo "$RESULT" | grep -q "workspace/$f"; then
          echo "      ✓ $f"
        else
          echo "      ✗ $f  MISSING"
          PLATFORM_PASS=false
        fi
      done

      echo "    Verifying skill files..."
      for skill in "${EXPECTED_SKILLS[@]}"; do
        if echo "$RESULT" | grep -q "skills/$skill/SKILL.md"; then
          echo "      ✓ $skill/SKILL.md"
        else
          echo "      ✗ $skill/SKILL.md  MISSING"
          PLATFORM_PASS=false
        fi
      done
    fi

    # Platform-specific adapter verification
    if ! $HAS_IDENTITY; then
      echo "    - No identity files, adapter skipped"
      if $PLATFORM_PASS; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
      continue
    fi

    echo "    Verifying adapter..."
    case "$PLATFORM" in
      claude-code)
        CLAUDE_MD=$(echo "$RESULT" | sed -n '/---ADAPTER_CLAUDE_MD---/,/---ADAPTER_AGENTS_MD---/p')
        if echo "$CLAUDE_MD" | grep -q "(not found)"; then
          echo "      ✗ .claude/CLAUDE.md not created"
          PLATFORM_PASS=false
        else
          for f in "${IDENTITY_FILES[@]}" "${KNOWLEDGE_FILES[@]}"; do
            if echo "$CLAUDE_MD" | grep -qF "@${f}"; then
              echo "      ✓ @${f}"
            else
              echo "      ✗ @${f}  MISSING in .claude/CLAUDE.md"
              PLATFORM_PASS=false
            fi
          done
        fi
        ;;

      openclaw)
        # OpenClaw reads from workspace root — verify identity files were copied
        INSTALLED=$(echo "$RESULT" | sed -n '/---INSTALLED_FILES---/,/---SKILL_FILES---/p')
        for f in SOUL.md IDENTITY.md; do
          if echo "$INSTALLED" | grep -q "workspace/$f"; then
            echo "      ✓ $f at workspace root"
          else
            echo "      ✗ $f NOT at workspace root"
            PLATFORM_PASS=false
          fi
        done
        # Root AGENTS.md should exist with knowledge appended
        ROOT_AGENTS=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD---/,/---ADAPTER_AGENTS_MD_SIZE---/p')
        if echo "$ROOT_AGENTS" | grep -q "(not found)"; then
          echo "      ✗ Root AGENTS.md not created"
          PLATFORM_PASS=false
        else
          echo "      ✓ Root AGENTS.md created"
          if [ ${#KNOWLEDGE_FILES[@]} -gt 0 ]; then
            if echo "$ROOT_AGENTS" | grep -q "# Knowledge Reference"; then
              echo "      ✓ Knowledge included in AGENTS.md"
            else
              echo "      ✗ Knowledge NOT included in AGENTS.md"
              PLATFORM_PASS=false
            fi
          fi
        fi
        ;;

      codex)
        ROOT_AGENTS=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD---/,/---ADAPTER_AGENTS_MD_SIZE---/p')
        if echo "$ROOT_AGENTS" | grep -q "(not found)"; then
          echo "      ✗ Root AGENTS.md not created"
          PLATFORM_PASS=false
        else
          # Check identity content is included by looking for first heading of each file
          for f in "${IDENTITY_FILES[@]}"; do
            first_heading=$(head -20 "$CAMP_DIR/$f" | grep -m1 '^#' | head -1 || true)
            if [ -n "$first_heading" ] && echo "$ROOT_AGENTS" | grep -qF "$first_heading"; then
              echo "      ✓ $f content included"
            elif [ -n "$first_heading" ]; then
              echo "      ✗ $f content missing from root AGENTS.md"
              PLATFORM_PASS=false
            else
              echo "      - $f (no heading to verify)"
            fi
          done
          # Check size <= 32KiB
          SIZE_LINE=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD_SIZE---/,/---ADAPTER_IDENTITY_AGENTS_MD---/p' | grep -E '^[0-9]+' | head -1 | tr -d '[:space:]')
          if [ -n "$SIZE_LINE" ] && [ "$SIZE_LINE" -le 32000 ]; then
            echo "      ✓ AGENTS.md size ${SIZE_LINE}B <= 32KiB"
          elif [ -n "$SIZE_LINE" ]; then
            echo "      ✗ AGENTS.md size ${SIZE_LINE}B exceeds 32KiB"
            PLATFORM_PASS=false
          fi
        fi
        # Verify .claude/CLAUDE.md was NOT created (codex doesn't need it)
        CLAUDE_MD=$(echo "$RESULT" | sed -n '/---ADAPTER_CLAUDE_MD---/,/---ADAPTER_AGENTS_MD---/p')
        if echo "$CLAUDE_MD" | grep -q "(not found)"; then
          echo "      ✓ No .claude/CLAUDE.md (correct for codex)"
        else
          echo "      ✗ Unexpected .claude/CLAUDE.md created"
          PLATFORM_PASS=false
        fi
        ;;
    esac

    if $PLATFORM_PASS; then
      echo "    => PASS"
      PASS=$((PASS + 1))
    else
      echo "    => FAIL"
      FAIL=$((FAIL + 1))
    fi
  done

  # -------------------------------------------------------
  # Test conflict cases (existing files in workspace)
  # -------------------------------------------------------
  if $HAS_IDENTITY; then
    for CONFLICT_CASE in claude-code codex; do
      echo ""
      echo "  --- Conflict: $CONFLICT_CASE (existing file) ---"
      CONFLICT_PASS=true

      case "$CONFLICT_CASE" in
        claude-code)
          PRESEED='mkdir -p workspace/.claude && echo "# My existing config" > workspace/.claude/CLAUDE.md'
          ;;
        codex)
          PRESEED='mkdir -p workspace && echo "# My existing agents" > workspace/AGENTS.md'
          ;;
      esac

      DOCKER_EXIT=0
      RESULT=$(run_installer "$DIST" "$CONFLICT_CASE" "$PRESEED") || DOCKER_EXIT=$?

      if [ "$DOCKER_EXIT" -ne 0 ]; then
        echo "    [error] Docker installer exited with code $DOCKER_EXIT"
        echo "$RESULT" | tail -20
        FAIL=$((FAIL + 1))
        continue
      fi

      STAGING=$(echo "$RESULT" | sed -n '/---ADAPTER_STAGING---/,/---ADAPTER_END---/p')

      echo "    Verifying conflict handling..."
      case "$CONFLICT_CASE" in
        claude-code)
          # Existing .claude/CLAUDE.md should be preserved
          CLAUDE_MD=$(echo "$RESULT" | sed -n '/---ADAPTER_CLAUDE_MD---/,/---ADAPTER_AGENTS_MD---/p')
          if echo "$CLAUDE_MD" | grep -q "My existing config"; then
            echo "      ✓ Existing .claude/CLAUDE.md preserved"
          else
            echo "      ✗ Existing .claude/CLAUDE.md was overwritten"
            CONFLICT_PASS=false
          fi
          # Camp context should be in staging file
          if echo "$STAGING" | grep -q "(not found)"; then
            echo "      ✗ .campforge-context.md not created"
            CONFLICT_PASS=false
          else
            echo "      ✓ .campforge-context.md created with camp context"
          fi
          # action-required message should be in output
          if echo "$RESULT" | grep -q "action-required"; then
            echo "      ✓ Merge instruction printed"
          else
            echo "      ✗ No merge instruction in output"
            CONFLICT_PASS=false
          fi
          ;;
        codex)
          # Existing AGENTS.md should be preserved
          ROOT_AGENTS=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD---/,/---ADAPTER_AGENTS_MD_SIZE---/p')
          if echo "$ROOT_AGENTS" | grep -q "My existing agents"; then
            echo "      ✓ Existing AGENTS.md preserved"
          else
            echo "      ✗ Existing AGENTS.md was overwritten"
            CONFLICT_PASS=false
          fi
          # Camp context should be in staging file
          if echo "$STAGING" | grep -q "(not found)"; then
            echo "      ✗ .campforge-context.md not created"
            CONFLICT_PASS=false
          else
            echo "      ✓ .campforge-context.md created with camp context"
          fi
          if echo "$RESULT" | grep -q "action-required"; then
            echo "      ✓ Merge instruction printed"
          else
            echo "      ✗ No merge instruction in output"
            CONFLICT_PASS=false
          fi
          ;;
      esac

      if $CONFLICT_PASS; then
        echo "    => PASS"
        PASS=$((PASS + 1))
      else
        echo "    => FAIL"
        FAIL=$((FAIL + 1))
      fi
    done
  fi

  rm -rf "$DIST"
done

echo ""
echo "========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================="
[ "$FAIL" -eq 0 ]
