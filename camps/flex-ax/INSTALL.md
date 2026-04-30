# flex-ax Camp Installation

> This document supplements `install.sh` — the primary installation method.
> For manual or Windows installation, refer to the sections below.

## Prerequisites

- Node.js >=20 and npm
- curl
- bash (Windows: use WSL, Git Bash, or see the PowerShell section)

On Windows, the installer will also try to bootstrap missing prerequisites via `winget`:
- `OpenJS.NodeJS.LTS`
- `Git.Git` (Git for Windows / Git Bash)

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
```

By default, the installer creates and uses `./workspace/`.
Override with `WORKSPACE=/your/path` if you want a different install location.

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

## Windows (PowerShell)

PowerShell install script is tracked in [planetarium/CampForge#32](https://github.com/planetarium/CampForge/issues/32).

Recommended setup on Windows:
- Use **Git Bash** as the default runtime shell for `flex-ax`, `gws`, and `gws-auth`
- Use PowerShell only for one-time file placement / PATH setup when needed
- If `Node.js` or `Git for Windows` is missing, the installer will try `winget install OpenJS.NodeJS.LTS` and `winget install Git.Git`

### Preferred path: Git Bash install

If Git Bash is available, use the normal installer:

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.sh | bash
```

After install, restart Git Bash or export the local bin directory:

```bash
export PATH="$(pwd)/.local/bin:$PATH"
flex-ax --version
gws --version
gws-auth --help
```

### Manual PowerShell setup

If you must place the tools manually from PowerShell:
- Download the standalone `flex-ax-windows-x64.exe` release asset
- Rename it to `flex-ax.exe`
- Put it in a user-writable bin directory such as `%USERPROFILE%\\.local\\bin`
- Add that directory to `PATH`
- Use `.cmd` wrappers instead of symlinks for Node-based CLI tools such as `gws` / `gws-auth`

Example:

```powershell
New-Item -ItemType Directory -Force "$HOME\.local\bin" | Out-Null
Copy-Item .\flex-ax-windows-x64.exe "$HOME\.local\bin\flex-ax.exe"
$env:PATH = "$HOME\.local\bin;$env:PATH"
flex-ax --version
```

For persistent PATH setup, add `%USERPROFILE%\.local\bin` to the user PATH in Windows settings.

Example `.cmd` wrapper for `gws-auth` (adjust path to match actual install location):
```cmd
@node "%~dp0\..\node_modules\@planetarium\gws-auth\bin\gws-auth.js" %*
```

### Post-install checks on Windows

Run these from **Git Bash** when possible:

```bash
flex-ax --version
flex-ax status
gws --version
gws-auth --help
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
flex-ax login
flex-ax status
flex-ax crawl
flex-ax import
```

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
export GOOGLE_WORKSPACE_CLI_TOKEN="$(gws-auth token)"
gws gmail users getProfile --params '{"userId":"me"}'
```
