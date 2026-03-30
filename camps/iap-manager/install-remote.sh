#!/usr/bin/env bash
# Remote installer for iap-manager skills (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/iap-manager/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# gql-ops (dependency)
mkdir -p "$WS/skills/gql-ops"
curl -sL "$BASE/packages/gql-ops/skills/gql-ops/SKILL.md" -o "$WS/skills/gql-ops/SKILL.md"

# iap-manager skills
for skill in iap-asset-import iap-image-upload iap-product-import iap-product-query iap-receipt-query; do
  mkdir -p "$WS/skills/${skill}"
  curl -sL "$BASE/camps/iap-manager/skills/${skill}/SKILL.md" -o "$WS/skills/${skill}/SKILL.md"
done

echo "iap-manager skills installed (with gql-ops dependency)"
