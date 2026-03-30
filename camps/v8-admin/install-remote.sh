#!/usr/bin/env bash
# Remote installer for v8-admin skill (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/v8-admin/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# gql-ops (dependency)
mkdir -p "$WS/skills/gql-ops"
curl -sL "$BASE/packages/gql-ops/skills/gql-ops/SKILL.md" -o "$WS/skills/gql-ops/SKILL.md"

# v8-admin
mkdir -p "$WS/skills/v8-admin/queries" "$WS/skills/v8-admin/references"
curl -sL "$BASE/camps/v8-admin/skills/v8-admin/SKILL.md" -o "$WS/skills/v8-admin/SKILL.md"
curl -sL "$BASE/camps/v8-admin/skills/v8-admin/v8-auth.sh" -o "$WS/skills/v8-admin/v8-auth.sh"
chmod +x "$WS/skills/v8-admin/v8-auth.sh"
curl -sL "$BASE/camps/v8-admin/skills/v8-admin/references/admin-api.md" -o "$WS/skills/v8-admin/references/admin-api.md"
for f in users-search users-low-balance comments-list verse-list game-payments-list game-payment-items-list; do
  curl -sL "$BASE/camps/v8-admin/skills/v8-admin/queries/${f}.gql" -o "$WS/skills/v8-admin/queries/${f}.gql"
done

echo "v8-admin skill installed (with gql-ops dependency)"
