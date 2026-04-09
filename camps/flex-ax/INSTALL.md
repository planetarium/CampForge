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
3. **CLI tools** — installs flex-ax, gws, gws-auth to `workspace/.local/bin/` (no global npm changes)
4. **Platform adapter** — detects agent platform and generates config files
5. **Freshness hook** — sets up auto data-refresh (platform-specific)

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
# Expected: flex-query/ flex-crawl/ gws-auth/ gws-sheets/ gws-gmail/ gws-drive/

flex-ax --version
gws --version
gws-auth --help
```

## Windows (PowerShell)

PowerShell install script is tracked in [planetarium/CampForge#32](https://github.com/planetarium/CampForge/issues/32).

Until available, the key differences for manual setup:
- Use `.cmd` wrappers instead of symlinks for CLI tools in `.local/bin/`
- `npm install --prefix .local <tgz>` works the same
- Platform adapter and skill installation steps are identical

Example `.cmd` wrapper for flex-ax (adjust path to match actual install location):
```cmd
@node "%~dp0\..\node_modules\flex-ax\dist\cli.js" %*
```

## Post-install: Authentication

### flex-ax (data crawling)

flex-ax crawl fetches HR data from the flex API. `import` converts the crawled JSON into the queryable format.

```bash
flex-ax crawl --auth playwriter   # preferred — reuses host Chrome session
flex-ax import                    # required — converts crawled JSON into queryable format
```

Alternative: `flex-ax crawl --auth credentials` (requires `FLEX_EMAIL`, `FLEX_PASSWORD` env vars).

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
