# flex-ax-remote Camp Installation

> This document supplements `install.sh` — the primary installation method.
> For manual or Windows installation, refer to the sections below.

## Prerequisites

- Node.js >=18 and npm
- curl
- `jq` (used by the post-install token-extraction snippet)
- bash (Windows: use WSL or Git Bash)

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax-remote/install.sh | bash
```

## What the script does

1. Skill packages — `npm pkg set` + `npx skillpm install`
2. Camp files — downloads tarball, extracts identity/, knowledge/, scripts/
3. CLI tools — installs a2x, gws, gws-auth into `workspace/.local/bin/`
4. Platform adapter — detects agent platform and generates config files

## Verify installation

```bash
export PATH="$(pwd)/.local/bin:$PATH"
ls .agents/skills/
a2x --version
gws --version
gws-auth --help
```

## Post-install: Authentication

```bash
export FLEX_HR_AGENT_URL="${FLEX_HR_AGENT_URL:-https://flex-hr-10780.fly.dev}"
export FLEX_HR_GQL="${FLEX_HR_AGENT_URL}/graphql"
export FLEX_HR_QUERIES_DIR="$(pwd)/knowledge/queries"

FLEX_HR_TOKEN="$(jq -er --arg u "$FLEX_HR_AGENT_URL" '.[$u][0].credential' ~/.a2x/tokens.json)" \
  && [ -n "$FLEX_HR_TOKEN" ] \
  || { echo "Missing cached Flex HR token for $FLEX_HR_AGENT_URL in ~/.a2x/tokens.json. Run 'a2x a2a send' first to authenticate." >&2; exit 1; }
export FLEX_HR_TOKEN
```

If there is no cached token yet, run:

```bash
a2x a2a send "$FLEX_HR_AGENT_URL" "ping"
```

Then approve the device-flow URL in a browser and re-run the export snippet above.
