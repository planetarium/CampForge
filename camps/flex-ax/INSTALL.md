# flex-ax Camp Installation

> This document supplements `install.sh` — the primary installation method.
> For manual or Windows installation, refer to the sections below.

## Prerequisites

- Node.js >=18 and npm
- curl
- bash (Windows: use WSL, Git Bash, or see the PowerShell section)

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
```

## What the script does

1. **Skill packages** — `npm pkg set` + `npx skillpm install` (skillpm resolves skill doc dependencies into `.agents/skills/`)
2. **Camp files** — downloads tarball, extracts identity/, knowledge/, scripts/
3. **CLI tools** — installs a2x, gws, gws-auth into `workspace/.local/bin/` (no global npm changes). On macOS, the a2x binary is ad-hoc signed during install so Gatekeeper does not kill it.
4. **Platform adapter** — detects agent platform and generates config files

### Platform detection

Auto-detected by the script:
- `openclaw` command or `OPENCLAW_WORKSPACE` env → OpenClaw
- `codex` command or `CODEX_HOME` env → Codex
- Otherwise → Claude Code

Override: `CAMPFORGE_PLATFORM=<platform> bash install.sh`

## Verify installation

The script adds `.local/bin/` to PATH during installation. If running in a new shell:

```bash
export PATH="$(pwd)/.local/bin:$PATH"
```

```bash
ls .agents/skills/
# Expected: a2x/ gql-ops/ gws-auth/ gws-sheets/ gws-gmail/ gws-drive/

a2x --version
gq --version  # install with `npm i -g graphqurl` if missing
gws --version
gws-auth --help
```

## Windows (PowerShell)

PowerShell install script is tracked in [planetarium/CampForge#32](https://github.com/planetarium/CampForge/issues/32).

Until available, the key differences for manual setup:
- The a2x Windows binary is `a2x-win-x64.exe`; rename to `a2x.exe` and place on PATH
- Use `.cmd` wrappers instead of symlinks for Node-based CLI tools in `.local/bin/`
- `npm install --prefix .local <tgz>` works the same
- Platform adapter and skill installation steps are identical

## Post-install: Authentication

### Flex HR (a2x → SIWE token → GraphQL)

The agent target is `${FLEX_HR_AGENT_URL:-https://flex-hr-10780.fly.dev}`.
Override `FLEX_HR_AGENT_URL` to point at a different workspace or staging
deployment.

This camp uses `a2x` only for the initial device-flow authentication. The
SIWE token it caches is then reused as a Bearer token against the
PostGraphile endpoint at `${FLEX_HR_AGENT_URL}/graphql`.

The first `a2x a2a send` call against the URL prompts for an
authentication method:

- **OAuth2 Device Flow** (recommended) — a2x prints a one-time URL
  containing a `user_code`. Open it in a browser and approve. Tokens are
  cached in `~/.a2x/tokens.json` per agent base URL.
- **SIWE Bearer** — wallet-based identity. Run `a2x wallet create` first,
  then pick this method when prompted.

After the first auth, export the token + endpoint env vars before any
data query:

```bash
export FLEX_HR_AGENT_URL="${FLEX_HR_AGENT_URL:-https://flex-hr-10780.fly.dev}"
export FLEX_HR_GQL="${FLEX_HR_AGENT_URL}/graphql"
export FLEX_HR_QUERIES_DIR="$(pwd)/knowledge/queries"   # absolute path

# Use `jq -er` so a missing/null cache entry fails fast instead of exporting "null".
FLEX_HR_TOKEN="$(jq -er --arg u "$FLEX_HR_AGENT_URL" '.[$u][0].credential' ~/.a2x/tokens.json)" \
  && [ -n "$FLEX_HR_TOKEN" ] \
  || { echo "Missing cached Flex HR token for $FLEX_HR_AGENT_URL in ~/.a2x/tokens.json. Run 'a2x a2a send' first to authenticate." >&2; exit 1; }
export FLEX_HR_TOKEN

# Smoke test
gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" \
  -q '{ __schema { queryType { name } } }' -l
```

Force a re-auth by deleting the entry for that URL from
`~/.a2x/tokens.json`. Detailed flow is in the `a2x` skill's SKILL.md
(`.agents/skills/a2x/SKILL.md`).

### Google Workspace

The agent can start the login flow; the user must complete browser consent.

```bash
gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file
```

Verify access after login:

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN="$(gws-auth token)"
gws gmail users getProfile --params '{"userId":"me"}'
```
