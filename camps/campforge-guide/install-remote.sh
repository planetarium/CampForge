#!/usr/bin/env bash
# Remote installer for campforge-guide camp (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/campforge-guide/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# campforge-guide skills
for skill in camp-add-skill camp-bench camp-create camp-sync camp-validate campforge-interview; do
  mkdir -p "$WS/skills/${skill}"
  curl -sL "$BASE/packages/${skill}/skills/${skill}/SKILL.md" -o "$WS/skills/${skill}/SKILL.md"
done

echo "campforge-guide camp installed"
