#!/usr/bin/env bash
# Remote installer for v8-admin camp
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/v8-admin/install-remote.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="${WORKSPACE:-workspace}"
mkdir -p "$WS"
cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/v8-admin=$BASE/campforge-v8-admin-1.0.0.tgz" \
  "dependencies.@campforge/gql-ops=$BASE/campforge-gql-ops-0.2.0.tgz" \
  "dependencies.@campforge/gws-sheets=$BASE/campforge-gws-sheets-0.1.0.tgz"

npx skillpm install

# Install gws: prefer musl binary on Linux (avoids glibc >=2.39 requirement from gnu build)
if [ "$(uname -s)" = "Linux" ]; then
  GWS_VERSION=$(curl -fsSL https://api.github.com/repos/googleworkspace/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  GWS_TARGET="x86_64-unknown-linux-musl" ;;
    aarch64) GWS_TARGET="aarch64-unknown-linux-musl" ;;
    *)       GWS_TARGET="" ;;
  esac
  if [ -n "$GWS_TARGET" ] && [ -n "$GWS_VERSION" ]; then
    curl -fsSL "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" | tar xz --strip-components=0 -C /usr/local/bin ./gws && \
      chmod +x /usr/local/bin/gws || echo "  [warn] gws musl binary install failed."
  else
    npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
  fi
else
  npm install -g @googleworkspace/cli 2>/dev/null || echo "  [warn] gws install failed."
fi
# gws-auth
npm install -g https://github.com/planetarium/gws-auth/releases/download/v0.3.0/anthropic-kr-gws-auth-0.1.0.tgz 2>/dev/null || \
  echo "  [warn] gws-auth install failed. Install manually."

echo "v8-admin camp installed (via skillpm + release tarball)"
