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
compatibility: Requires gws (@googleworkspace/cli) installed and authenticated
---

# Google Sheets Skill (gws CLI)

## Environment variables

```bash
echo $GWS_SPREADSHEET_ID   # Default spreadsheet ID (optional — can be passed per command)
```

If user doesn't specify a spreadsheet ID, ask for it.

### Installation

```bash
npm install -g @googleworkspace/cli
```

Verify: `gws --version`

### Authentication

**You MUST run this yourself** before any gws call — do NOT ask the user to run it manually.

Try methods in order until one succeeds:

#### Method 1: gcloud ADC (추천 — 별도 OAuth 클라이언트 설정 불필요)

gcloud CLI가 설치·인증된 환경에서 가장 간편한 방법.
Sheets/Drive 스코프를 포함한 ADC(Application Default Credentials)를 발급받아 사용:

```bash
# ADC가 이미 있는지 확인
gcloud auth application-default print-access-token 2>/dev/null && echo "ADC OK"
```

ADC가 없거나 스코프가 부족하면 사용자에게 아래 명령 실행을 요청 (브라우저 동의 1회 필요):

```bash
gcloud auth application-default login \
  --scopes="https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/userinfo.email,openid"
```

이후 매 호출 전 토큰 주입:

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gcloud auth application-default print-access-token)
```

#### Method 2: OAuth Client ID/Secret (gcloud 없는 환경)

GCP Console에서 Desktop app OAuth 클라이언트를 만들어 환경변수로 주입:

```bash
export GOOGLE_WORKSPACE_CLI_CLIENT_ID="<client-id>.apps.googleusercontent.com"
export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="<client-secret>"
gws auth login
```

- `gws auth login`이 브라우저 URL을 출력 → 사용자가 열어서 동의
- 이후 캐시된 credential로 자동 인증 (AES-256-GCM, OS keyring에 저장)
- Client ID는 공개해도 무방. Client Secret은 시크릿 매니저나 환경변수로 관리

#### Method 3: Service Account (CI/headless — 브라우저 없는 환경)

```bash
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="/path/to/sa-key.json"
```

- SA 키 JSON 파일은 절대 커밋 금지. CI secrets로 주입
- 대상 스프레드시트에 SA 이메일을 편집자로 공유해야 접근 가능

#### Method 4: Pre-obtained Token (임시 사용)

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN="ya29.xxx..."
```

- 1시간 후 만료. 장기 사용 불가. 디버깅/테스트용

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

**Combine independent gws calls into a single Bash call with `;`:**

```bash
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
