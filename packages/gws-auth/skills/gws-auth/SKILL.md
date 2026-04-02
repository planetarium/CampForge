---
name: gws-auth
description: >
  Google Workspace CLI authentication and environment setup. Handles
  gws and gws-auth installation, OAuth login, token injection, and
  project ID configuration. This skill is a shared dependency for
  gws-sheets, gws-gmail, and other gws-based skills.
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires gws (@googleworkspace/cli) ≥0.22.3 and gws-auth (github:planetarium/gws-auth) ≥0.4.0
---

# Google Workspace Auth Skill

## Environment variables

```bash
echo $GOOGLE_WORKSPACE_PROJECT_ID  # GCP project ID for API quota (required)
```

If `$GOOGLE_WORKSPACE_PROJECT_ID` is not set, ask user. This MUST be the GCP project that owns the gws-auth OAuth Client ID. Using a different project causes `403 serviceusage.services.use` permission errors on write operations.

## Installation

```bash
npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.4.0/anthropic-kr-gws-auth-0.1.0.tgz
```

> **Note**: The tarball is named `0.1.0` (npm package version) while the GitHub release tag is `v0.4.0` (CLI release version). This is expected — the npm package version and the release tag are versioned independently.

Verify: `gws --version && gws-auth --help`

## Authentication (gws-auth)

`gws-auth` is a dedicated OAuth CLI with embedded Client ID/Secret — no manual GCP credentials setup required.

### Auth flow selection

gws-auth v0.4.0+ uses the **authorization code flow** (localhost redirect) which supports all Google Workspace scopes. Older versions (≤0.3.0) used the device code flow, which Google restricts to only 7 scopes (openid, email, profile, drive.appdata, drive.file, youtube, youtube.readonly). **Gmail and Calendar scopes require v0.4.0+.**

### 1. Check login status

```bash
gws-auth status 2>/dev/null && echo "AUTH OK"
```

If not logged in, **ask the user** to run the login command (requires one-time Google OAuth consent in a browser — the agent cannot run this directly):

```bash
gws-auth login
```

Default scopes are `spreadsheets` and `drive.file`. To request additional scopes:

```bash
gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file
```

When re-logging in, include all desired scopes (existing scopes are not automatically retained).

### 2. Export token and project before each call

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN="$(gws-auth token)"
export GOOGLE_WORKSPACE_PROJECT_ID
```

### Available scopes

| Alias | Description |
|-------|-------------|
| `spreadsheets` | Google Sheets read/write (default) |
| `drive.file` | Drive files created by the app (default) |
| `drive` | Full Drive access |
| `drive.readonly` | Drive read-only |
| `gmail.modify` | Gmail read + write + label management |
| `gmail.readonly` | Gmail read-only |
| `gmail.send` | Gmail send-only |
| `calendar` | Google Calendar read/write |
| `calendar.readonly` | Google Calendar read-only |
| `docs` | Google Docs read/write |
| `docs.readonly` | Google Docs read-only |

Full list: `gws-auth scopes`

## IMPORTANT: Token Optimization

**Combine independent gws calls into a single Bash call with `;`. Export the token once at the top:**

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gws-auth token)
echo "=== Step 1 ===" ; gws <service> <command1> 2>&1
echo "=== Step 2 ===" ; gws <service> <command2> 2>&1
```

## Discover commands

```bash
# List all services
gws --help

# Inspect method signature
gws schema <service.resource.method>

# Dry-run (preview request without executing)
gws <service> <command> --dry-run
```
