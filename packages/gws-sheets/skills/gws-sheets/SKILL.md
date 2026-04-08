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
compatibility: Requires @campforge/gws-auth skill package (^0.1.0).
---

# Google Sheets Skill (gws CLI)

Authentication, installation, and token setup are handled by the **gws-auth** skill. Before proceeding, load/activate the `@campforge/gws-auth` skill dependency. If not already authenticated, the **user** must run `gws-auth login` themselves — the agent cannot perform this interactive browser OAuth step. The default scopes (`spreadsheets`, `drive.file`) are sufficient for core Sheets read/write operations and for accessing spreadsheets the app creates or opens. Drive-wide operations such as listing/searching files or managing sharing/permissions for arbitrary files (e.g., `gws drive files list`, `gws drive permissions create`) may require additional Drive scopes (`drive.readonly` or `drive`), which can be configured via **gws-auth**.

## Environment variables

```bash
echo $GWS_SPREADSHEET_ID  # Default spreadsheet ID (optional — can be passed per command)
```

If `$GWS_SPREADSHEET_ID` is not set and user doesn't specify one, ask for it.

## How to call

### Skill shortcuts (simple interface)

```bash
# Read values
gws sheets +read --spreadsheet <SPREADSHEET_ID> --range "Sheet1!A1:D10"

# Read entire sheet
gws sheets +read --spreadsheet <SPREADSHEET_ID> --range Sheet1

# Append single row
gws sheets +append --spreadsheet <SPREADSHEET_ID> --values 'Alice,95,2026-03-30'

# Append multiple rows
gws sheets +append --spreadsheet <SPREADSHEET_ID> --json-values '[["Name","Score"],["Alice",95]]'
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
3. `gws sheets +append --spreadsheet <ID> --json-values '[["col1","col2",...]]'`
4. Re-read to verify

### Create new spreadsheet with initial data

1. `gws sheets spreadsheets create --json '{"properties": {"title": "..."}}'` -> get new spreadsheet ID
2. `gws sheets +append --spreadsheet <NEW_ID> --json-values '[["Header1","Header2"],[...]]'`
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
- **Windows**: `--params` / `--json` examples are bash syntax. On Windows, use Git Bash — PowerShell mangles JSON quotes passed to native executables
