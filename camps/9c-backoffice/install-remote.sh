#!/usr/bin/env bash
# Remote installer for 9c-backoffice skill (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/9c-backoffice/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# gql-ops (dependency)
mkdir -p "$WS/skills/gql-ops"
curl -sL "$BASE/packages/gql-ops/skills/gql-ops/SKILL.md" -o "$WS/skills/gql-ops/SKILL.md"

# 9c-backoffice
mkdir -p "$WS/skills/9c-backoffice/queries" "$WS/skills/9c-backoffice/references"
curl -sL "$BASE/camps/9c-backoffice/skills/9c-backoffice/SKILL.md" -o "$WS/skills/9c-backoffice/SKILL.md"
curl -sL "$BASE/camps/9c-backoffice/skills/9c-backoffice/references/api-endpoints.md" -o "$WS/skills/9c-backoffice/references/api-endpoints.md"
for f in check-deleted-addresses sheet-compare sheet-list table-patch-purge-cache table-patch-sign table-patch-stage table-patch-tx-result table-patch-upload-r2 table-patch-validate; do
  curl -sL "$BASE/camps/9c-backoffice/skills/9c-backoffice/queries/${f}.gql" -o "$WS/skills/9c-backoffice/queries/${f}.gql"
done

echo "9c-backoffice skill installed (with gql-ops dependency)"
