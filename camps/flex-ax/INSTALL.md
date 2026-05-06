# flex-ax Camp Installation

> This document supplements `install.sh` — the primary installation method.
> For Windows usage notes, refer to the section below.

## Prerequisites

- Node.js >=20 and npm
- curl
- bash (Windows: use Git Bash)

On Windows, the installer will also try to bootstrap missing prerequisites via `winget`:
- `OpenJS.NodeJS.LTS`
- `Git.Git` (Git for Windows / Git Bash)

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
```

By default, the installer creates and uses `./workspace/`.
Override with `WORKSPACE=/your/path` if you want a different install location.
If the path contains spaces, quote it: `WORKSPACE=\"/path/with spaces\" bash install.sh`.

On Windows, run this command from **Git Bash**, not from PowerShell. In
PowerShell, `curl` may resolve to `Invoke-WebRequest` instead of the curl
executable expected by the pipe-to-bash install command.

## What the script does

1. **Skill packages** — `npm pkg set` + `npx skillpm install` (skillpm resolves skill doc dependencies into `.agents/skills/`)
2. **Camp files** — downloads tarball, extracts identity/, knowledge/, scripts/
3. **CLI tools** — installs the standalone `flex-ax` executable plus gws, gws-auth to `workspace/.local/bin/` (no global npm changes)
4. **Platform adapter** — detects agent platform and generates config files
5. **Freshness hook** — sets up auto data-refresh (platform-specific)

### Platform detection

Auto-detected by the script:
- `openclaw` command or `OPENCLAW_WORKSPACE` env → OpenClaw
- `codex` command or `CODEX_HOME` env → Codex
- Otherwise → Claude Code

Override: `CAMPFORGE_PLATFORM=<platform> bash install.sh`

## Verify installation

If you used the default install path, move into the generated workspace first:

```bash
cd workspace
```

The script adds `.local/bin/` to PATH during installation. If running in a new shell:

```bash
export PATH="$(pwd)/.local/bin:$PATH"
```

```bash
ls .agents/skills/
# Expected: flex-query/ flex-crawl/ gws-auth/ gws-sheets/ gws-gmail/ gws-drive/

flex-ax --version
gws --version
command -v gws-auth
```

## Windows

Use **Git Bash** as the default runtime shell for `flex-ax`, `gws`, and `gws-auth`.
If `Node.js` or `Git for Windows` is missing, the installer will try `winget install OpenJS.NodeJS.LTS` and `winget install Git.Git`.

Install with the normal command from Git Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
```

After install, restart Git Bash or export the local bin directory:

```bash
export PATH="$(pwd)/.local/bin:$PATH"
flex-ax --version
gws --version
command -v gws-auth
```

For SQL checks on Windows, keep using Git Bash so `OUTPUT_DIR` and quoting
behave the same way as the installer:

```bash
export OUTPUT_DIR="$(pwd)/output/<customerIdHash>"
flex-ax query "SELECT * FROM users LIMIT 5"
```

If `flex-ax query` fails later with an export-dir error, point `OUTPUT_DIR` at a concrete export directory before querying:

```bash
export OUTPUT_DIR="$HOME/.flex-ax-data/output/<customerIdHash>"
flex-ax query "SELECT * FROM users LIMIT 5"
```

## Post-install: Authentication

### flex-ax (credentials + crawl)

Since `flex-cli@0.7.0`, the official install is a standalone executable and the recommended auth flow is `login` / OS keyring storage.

```bash
flex-ax login --gui
flex-ax status
flex-ax crawl
flex-ax import
```

Use `flex-ax login --gui` for Codex, CI-adjacent terminals, and other
non-interactive agent environments. It opens a platform dialog and avoids
stdin/password prompt issues. Plain `flex-ax login` is still fine in a fully
interactive shell.

Non-interactive environments can still use env vars:

```bash
export FLEX_EMAIL="you@example.com"
export FLEX_PASSWORD="..."
flex-ax crawl
flex-ax import
```

Notes:
- `flex-ax login` stores the email in `~/.flex-ax/config.json`
- The password is stored in the OS keyring, or can be injected via `FLEX_PASSWORD` / `--password-stdin`
- `query` now expects `OUTPUT_DIR` to point at a concrete export directory when multiple customer exports exist
- Run `flex-ax query` commands sequentially. The imported SQLite database can
  report `database is locked` or `disk I/O error` when multiple agent queries
  read it concurrently.

Example:

```bash
export OUTPUT_DIR="$HOME/.flex-ax-data/output/<customerIdHash>"
flex-ax query "SELECT * FROM users LIMIT 5"
```

### Google Workspace

The agent can start the login flow; the user must complete browser consent.

```bash
gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file
```

Verify access after login:

```bash
gws-auth status
export GOOGLE_WORKSPACE_CLI_TOKEN="$(gws-auth token)"
gws gmail users getProfile --params '{"userId":"me"}'
```

If a required scope is missing from `gws-auth status`, run `gws-auth login`
again with the full scope list.
