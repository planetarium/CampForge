#!/bin/bash
# CampForge campforge-guide adapter — generic fallback

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 1. Install all skills via skillpm
cd "$CAMP_DIR" && npx skillpm install

echo ":: CampForge campforge-guide installed (generic)"
