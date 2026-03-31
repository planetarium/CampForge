#!/bin/bash
# CampForge v8-admin adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 1. Install all skills via skillpm
cd "$CAMP_DIR" && npx skillpm install

# 2. Install gws + gws-auth (for gws-sheets skill)
npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
  echo "  [warn] gws/gws-auth install failed. Install manually."

echo ":: CampForge v8-admin installed (generic)"
