---
name: gws-sheets
description: >
  Google Sheets operations via gws (Google Workspace CLI). Use when asked to
  read, write, append, or manage spreadsheets in Google Drive. Triggers on
  requests like "read the spreadsheet", "append rows to sheet", "create a
  new spreadsheet", "list Drive files", "share sheet with team".
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires gws (@googleworkspace/cli) and gws-auth (github:planetarium/gws-auth)
---

# Google Sheets Skill (gws CLI)

## Environment variables

```bash
echo $GWS_SPREADSHEET_ID   # Default spreadsheet ID (optional — can be passed per command)
```

If user doesn't specify a spreadsheet ID, ask for it.

### Installation

```bash
npm install -g @googleworkspace/cli github:planetarium/gws-auth
```

Verify: `gws --version && gws-auth --help`

### Authentication (gws-auth)

**You MUST run this yourself** before any gws call — do NOT ask the user to run it manually.

`gws-auth`는 OAuth 인증 전용 CLI로, Client ID/Secret이 내장되어 있어 별도 GCP 설정이 필요 없다.

#### 1. 로그인 상태 확인

```bash
gws-auth status 2>/dev/null && echo "AUTH OK"
```

로그인되어 있지 않으면 사용자에게 아래 실행을 요청 (브라우저 동의 1회 필요):

```bash
gws-auth login
```

#### 2. 매 호출 전 토큰 주입

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gws-auth token)
```

## How to call

### Skill shortcuts (simple interface)

```bash
# Read values
gws sheets +read --spreadsheet <SPREADSHEET_ID> --range "Sheet1!A1:D10"

# Read entire sheet
gws sheets +read --spreadsheet <SPREADSHEET_ID> --range Sheet1

# Append rows
gws sheets +append --spreadsheet <SPREADSHEET_ID> --range "Sheet1!A1" \
  --values '[["Name","Score"],["Alice",95]]'
```

### Direct API commands

```bash
# Create spreadsheet
gws sheets spreadsheets create --json '{"properties": {"title": "New Sheet"}}'

# Get values from range
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "<ID>", "range": "Sheet1!A1:C10"}'

# Update values (overwrite)
gws sheets spreadsheets values update \
  --params '{"spreadsheetId": "<ID>", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["Name", "Score"], ["Alice", 95]]}'

# Append values
gws sheets spreadsheets values append \
  --params '{"spreadsheetId": "<ID>", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["Bob", 88]]}'

# Batch update (formatting, merges, conditional formatting, etc.)
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId": "<ID>"}' \
  --json '{"requests": [...]}'

# Clear range
gws sheets spreadsheets values clear \
  --params '{"spreadsheetId": "<ID>", "range": "Sheet1!A1:D10"}'
```

### Google Drive (spreadsheet file operations)

```bash
# List spreadsheets in Drive
gws drive files list --params '{"q": "mimeType=\"application/vnd.google-apps.spreadsheet\"", "pageSize": 20}'

# Search by name
gws drive files list --params '{"q": "name contains \"Budget\" and mimeType=\"application/vnd.google-apps.spreadsheet\"", "pageSize": 10}'

# Share spreadsheet
gws drive permissions create \
  --params '{"fileId": "<SPREADSHEET_ID>"}' \
  --json '{"role": "writer", "type": "user", "emailAddress": "user@example.com"}'

# Get file metadata
gws drive files get --params '{"fileId": "<SPREADSHEET_ID>", "fields": "id,name,webViewLink,modifiedTime"}'
```

## IMPORTANT: Token Optimization

**Combine independent gws calls into a single Bash call with `;`. 토큰은 먼저 한번만 export:**

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gws-auth token)
echo "=== Sheet Data ===" ; gws sheets +read --spreadsheet "$GWS_SPREADSHEET_ID" --range "Sheet1!A1:D10" 2>&1
echo "=== File Info ===" ; gws drive files get --params "{\"fileId\": \"$GWS_SPREADSHEET_ID\", \"fields\": \"id,name,modifiedTime\"}" 2>&1
```

## Discover commands

```bash
# List all sheets subcommands
gws sheets --help

# Inspect method signature
gws schema sheets.spreadsheets.values.get

# Dry-run (preview request without executing)
gws sheets +read --spreadsheet <ID> --range Sheet1 --dry-run
```

## Common Workflows

### Read spreadsheet and summarize

1. `gws sheets +read --spreadsheet <ID> --range Sheet1` -> get all data
2. Summarize or analyze the data as requested

### Append new rows from data

1. `gws sheets +read --spreadsheet <ID> --range "Sheet1!1:1"` -> get headers
2. Format new data to match header columns
3. `gws sheets +append --spreadsheet <ID> --range "Sheet1!A1" --values '[...]'`
4. Re-read to verify

### Create new spreadsheet with initial data

1. `gws sheets spreadsheets create --json '{"properties": {"title": "..."}}'` -> get new spreadsheet ID
2. `gws sheets +append --spreadsheet <NEW_ID> --range "Sheet1!A1" --values '[["Header1","Header2"],[...]]'`
3. Optionally share: `gws drive permissions create ...`

### Find and update specific spreadsheet

1. `gws drive files list --params '{"q": "name contains \"keyword\""}'` -> find spreadsheet
2. `gws sheets +read --spreadsheet <ID> --range Sheet1` -> read current data
3. `gws sheets spreadsheets values update ...` -> update specific range

## Notes

- `+read`, `+append` are gws skill shortcuts (simpler syntax than direct API)
- `--dry-run` flag previews the HTTP request without executing
- `--page-all` flag auto-paginates large result sets (NDJSON output)
- Spreadsheet ID is the long string in the URL: `docs.google.com/spreadsheets/d/<SPREADSHEET_ID>/edit`
- `valueInputOption`: `USER_ENTERED` (parses formulas) vs `RAW` (literal strings)
