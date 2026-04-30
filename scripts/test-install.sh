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
      echo "---CLI_TOOLS---"
      for tool in a2x flex-ax gws gws-auth gq; do
        command -v "$tool" 2>/dev/null && echo "${tool}=ok" || echo "${tool}=(not found)"
      done
      echo "---HOOKS---"
      cat workspace/.claude/settings.json 2>/dev/null || echo "(no settings.json)"
      echo "---BOOT_MD---"
      cat workspace/BOOT.md 2>/dev/null || echo "(no BOOT.md)"
      echo "---CAMP_SCRIPTS---"
      find workspace/scripts -type f 2>/dev/null | sort || echo "(no scripts/)"
      echo "---ADAPTER_STAGING---"
      cat workspace/.campforge-context*.md 2>/dev/null || echo "(not found)"
      echo "---ADAPTER_END---"
      kill $SERVER_PID 2>/dev/null || true
    ' 2>&1
}

run_installer_with_workspace() {
  local dist="$1" platform="$2" workspace_name="$3"
  docker run --rm \
    -v "$dist:/srv" \
    -e "CAMPFORGE_PLATFORM=$platform" \
    -e "WORKSPACE_NAME=$workspace_name" \
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
      WORKSPACE="$WORKSPACE_NAME" bash /srv/install.sh 2>&1
      echo "---SPACE_WORKSPACE_SKILLS---"
      find "$WORKSPACE_NAME/.agents/skills" -maxdepth 2 -name SKILL.md -type f 2>/dev/null | sort
      echo "---SPACE_WORKSPACE_HOOKS---"
      cat "$WORKSPACE_NAME/.claude/settings.json" 2>/dev/null || echo "(no settings.json)"
      kill $SERVER_PID 2>/dev/null || true
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

  # 2. Pre-fetch external CLI tarballs for E2E testing.
  #    If the camp provides tests/fetch-tools.sh, run it on the host (where
  #    gh auth is available). The script outputs lines: name|filename|install-cmd
  #    We build sed expressions to replace install_<name> with local HTTP installs.
  TOOL_SED_ARGS=(-e 's|^BASE=.*|BASE="http://localhost:8080"|')
  EXPECTED_CLI_TOOLS=()

  FETCH_SCRIPT="$CAMP_DIR/tests/fetch-tools.sh"
  if [ -x "$FETCH_SCRIPT" ]; then
    FETCH_OUTPUT=$(bash "$FETCH_SCRIPT" "$DIST" 2>&1) || true

    while IFS='|' read -r TOOL_NAME TOOL_FILE TOOL_INSTALL; do
      [ -z "$TOOL_NAME" ] && continue
      echo "$TOOL_NAME" | grep -q '^\[' && continue  # skip warning lines
      FUNC_NAME="install_$(echo "$TOOL_NAME" | tr '-' '_')"

      if [ -f "$DIST/$TOOL_FILE" ]; then
        LOCAL_INSTALL=$(echo "$TOOL_INSTALL" | sed "s|{file}|http://localhost:8080/$TOOL_FILE|g")
        TOOL_SED_ARGS+=(-e "s|^${FUNC_NAME}\$|${LOCAL_INSTALL}|")
        EXPECTED_CLI_TOOLS+=("$TOOL_NAME")
        echo "  Fetched $TOOL_NAME -> $TOOL_FILE"
      else
        echo "  [warn] $TOOL_NAME: $TOOL_FILE not found in $DIST, will skip"
        TOOL_SED_ARGS+=(-e "s|^${FUNC_NAME}\$|# skip: ${FUNC_NAME} (fetch failed)|")
      fi
    done <<< "$FETCH_OUTPUT"
  fi

  # Skip remaining install_* helpers not handled by fetch-tools.sh
  while IFS= read -r INSTALL_FUNC; do
    [ -z "$INSTALL_FUNC" ] && continue
    ALREADY_HANDLED=false
    for sed_arg in "${TOOL_SED_ARGS[@]}"; do
      echo "$sed_arg" | grep -qF "$INSTALL_FUNC" && { ALREADY_HANDLED=true; break; }
    done
    $ALREADY_HANDLED || TOOL_SED_ARGS+=(-e "s|^${INSTALL_FUNC}\$|# skip: ${INSTALL_FUNC}|")
  done < <(grep -oE '^install_[a-z_]+' "$CAMP_DIR/install.sh" 2>/dev/null | sort -u)

  # 3. Build a test install script with all substitutions
  sed "${TOOL_SED_ARGS[@]}" "$CAMP_DIR/install.sh" > "$DIST/install.sh"

  # 3. Collect expected files
  EXPECTED_CAMP=()
  for f in identity/SOUL.md identity/IDENTITY.md identity/AGENTS.md knowledge/glossary.md manifest.yaml; do
    [ -f "$CAMP_DIR/$f" ] && EXPECTED_CAMP+=("$f")
  done

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

  # HAS_CONTEXT: true if any identity or knowledge files exist
  HAS_CONTEXT=false
  if [ ${#IDENTITY_FILES[@]} -gt 0 ] || [ ${#KNOWLEDGE_FILES[@]} -gt 0 ]; then
    HAS_CONTEXT=true
  fi

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

    # Common checks: camp files + skills + CLI tools + hooks (claude-code and openclaw)
    if [ "$PLATFORM" = "claude-code" ] || [ "$PLATFORM" = "openclaw" ]; then
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

      # Verify CLI tools declared with test_fetch were installed
      if [ ${#EXPECTED_CLI_TOOLS[@]} -gt 0 ]; then
        echo "    Verifying CLI tools..."
        CLI_TOOLS=$(echo "$RESULT" | sed -n '/---CLI_TOOLS---/,/---HOOKS---/p')
        for tool in "${EXPECTED_CLI_TOOLS[@]}"; do
          if echo "$CLI_TOOLS" | grep -q "^${tool}=ok"; then
            echo "      ✓ $tool installed"
          else
            echo "      ✗ $tool NOT installed"
            PLATFORM_PASS=false
          fi
        done
      fi

      # Verify hooks and scripts (if camp has freshness check)
      if [ -f "$CAMP_DIR/scripts/check-freshness.sh" ]; then
        SCRIPTS_SECTION=$(echo "$RESULT" | sed -n '/---CAMP_SCRIPTS---/,/---ADAPTER_STAGING---/p')

        echo "    Verifying freshness hooks..."
        if echo "$SCRIPTS_SECTION" | grep -q "check-freshness.sh"; then
          echo "      ✓ scripts/check-freshness.sh installed"
        else
          echo "      ✗ scripts/check-freshness.sh MISSING"
          PLATFORM_PASS=false
        fi

        case "$PLATFORM" in
          claude-code)
            HOOKS_SECTION=$(echo "$RESULT" | sed -n '/---HOOKS---/,/---BOOT_MD---/p')
            if echo "$HOOKS_SECTION" | grep -q "UserPromptSubmit"; then
              echo "      ✓ .claude/settings.json has UserPromptSubmit hook"
            elif echo "$HOOKS_SECTION" | grep -q "(no settings.json)"; then
              echo "      ✗ .claude/settings.json not created"
              PLATFORM_PASS=false
            fi
            ;;
          openclaw)
            BOOT_SECTION=$(echo "$RESULT" | sed -n '/---BOOT_MD---/,/---CAMP_SCRIPTS---/p')
            if echo "$BOOT_SECTION" | grep -q "check-freshness"; then
              echo "      ✓ BOOT.md has freshness check"
            elif echo "$BOOT_SECTION" | grep -q "(no BOOT.md)"; then
              echo "      ✗ BOOT.md not created"
              PLATFORM_PASS=false
            fi
            ;;
        esac
      fi
    fi

    # Platform-specific adapter verification
    if ! $HAS_CONTEXT; then
      echo "    - No context files, adapter skipped"
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
          [ -f "$CAMP_DIR/identity/$f" ] || continue
          if echo "$INSTALLED" | grep -q "workspace/$f"; then
            echo "      ✓ $f at workspace root"
          else
            echo "      ✗ $f NOT at workspace root"
            PLATFORM_PASS=false
          fi
        done
        # Root AGENTS.md is only created when identity/AGENTS.md or knowledge exists
        if [ -f "$CAMP_DIR/identity/AGENTS.md" ] || [ ${#KNOWLEDGE_FILES[@]} -gt 0 ]; then
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
          SIZE_LINE=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD_SIZE---/,/---ADAPTER_IDENTITY_AGENTS_MD---/p' | tr -d '[:space:]' | grep -oE '[0-9]+' | head -1)
          if [ -n "$SIZE_LINE" ] && [ "$SIZE_LINE" -le 32768 ]; then
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

  if [ "$CAMP" = "flex-ax" ]; then
    echo ""
    echo "  --- Workspace Path With Spaces ---"
    SPACE_RESULT=$(run_installer_with_workspace "$DIST" "claude-code" "workspace with spaces")
    SPACE_PASS=true

    echo "    Verifying skill install under spaced workspace path..."
    for skill in "${EXPECTED_SKILLS[@]}"; do
      if echo "$SPACE_RESULT" | grep -q "workspace with spaces/.agents/skills/$skill/SKILL.md"; then
        echo "      ✓ $skill/SKILL.md"
      else
        echo "      ✗ $skill/SKILL.md MISSING"
        SPACE_PASS=false
      fi
    done

    echo "    Verifying freshness hook command quoting..."
    if echo "$SPACE_RESULT" | grep -Fq '"command": "bash \"/tmp/workspace with spaces/scripts/check-freshness.sh\""'; then
      echo "      ✓ .claude/settings.json quotes spaced script path"
    else
      echo "      ✗ .claude/settings.json does not quote spaced script path"
      SPACE_PASS=false
    fi

    if $SPACE_PASS; then
      echo "    => PASS"
      PASS=$((PASS + 1))
    else
      echo "    => FAIL"
      FAIL=$((FAIL + 1))
    fi
  fi

  # -------------------------------------------------------
  # Test conflict cases (existing files in workspace)
  # -------------------------------------------------------
  if $HAS_CONTEXT; then
    for CONFLICT_CASE in claude-code openclaw codex; do
      echo ""
      echo "  --- Conflict: $CONFLICT_CASE (existing file) ---"
      CONFLICT_PASS=true

      case "$CONFLICT_CASE" in
        claude-code)
          PRESEED='mkdir -p workspace/.claude && echo "# My existing config" > workspace/.claude/CLAUDE.md'
          ;;
        openclaw)
          PRESEED='mkdir -p workspace && echo "# My existing soul" > workspace/SOUL.md && echo "# My existing agents" > workspace/AGENTS.md'
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
        openclaw)
          # Existing root content should be preserved (appended, not overwritten)
          ROOT_AGENTS=$(echo "$RESULT" | sed -n '/---ADAPTER_AGENTS_MD---/,/---ADAPTER_AGENTS_MD_SIZE---/p')
          if echo "$ROOT_AGENTS" | grep -q "My existing agents"; then
            echo "      ✓ Existing AGENTS.md content preserved"
          else
            echo "      ✗ Existing AGENTS.md content was lost"
            CONFLICT_PASS=false
          fi
          # Camp identity should be appended to existing files
          if echo "$ROOT_AGENTS" | grep -q "Knowledge Reference\|AGENTS"; then
            echo "      ✓ Camp content appended to AGENTS.md"
          else
            echo "      ✗ Camp content not appended to AGENTS.md"
            CONFLICT_PASS=false
          fi
          if echo "$RESULT" | grep -q "Appended"; then
            echo "      ✓ Append operation logged"
          else
            echo "      ✗ No append log in output"
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
