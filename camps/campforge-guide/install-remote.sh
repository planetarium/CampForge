#!/usr/bin/env bash
# Remote installer for campforge-guide skills (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/campforge-guide/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# gql-ops (dependency)
mkdir -p "$WS/skills/gql-ops"
curl -sL "$BASE/packages/gql-ops/skills/gql-ops/SKILL.md" -o "$WS/skills/gql-ops/SKILL.md"

# campforge-guide skills
for skill in camp-add-skill camp-bench camp-create camp-sync camp-validate; do
  mkdir -p "$WS/skills/${skill}"
  curl -sL "$BASE/camps/campforge-guide/skills/${skill}/SKILL.md" -o "$WS/skills/${skill}/SKILL.md"
done

echo "campforge-guide skills installed (with gql-ops dependency)"
