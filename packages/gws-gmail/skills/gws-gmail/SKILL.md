---
name: gws-gmail
description: >
  Gmail operations via gws (Google Workspace CLI). Use when asked to
  read, send, reply, forward, or manage email. Triggers on requests like
  "check my inbox", "send an email", "reply to that message",
  "forward this to Alice", "triage unread mail", "watch for new emails".
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires gws (@googleworkspace/cli) ≥0.22.3 and gws-auth (github:planetarium/gws-auth) ≥0.4.0
---

# Gmail Skill (gws CLI)

## Environment variables

```bash
echo $GOOGLE_WORKSPACE_PROJECT_ID  # GCP project ID for API quota (required)
```

If `$GOOGLE_WORKSPACE_PROJECT_ID` is not set, ask user. This MUST be the GCP project that owns the gws-auth OAuth Client ID. Using a different project causes `403 serviceusage.services.use` permission errors on write operations (send, reply, forward). Read operations (triage, read) may work without it, but writes will fail.

### Installation

```bash
npm install -g @googleworkspace/cli https://github.com/planetarium/gws-auth/releases/download/v0.4.0/anthropic-kr-gws-auth-0.1.0.tgz
```

Verify: `gws --version && gws-auth --help`

### Authentication (gws-auth)

`gws-auth`는 OAuth 인증 전용 CLI로, Client ID/Secret이 내장되어 있어 별도 GCP 설정이 필요 없다.

**v0.4.0 필수**: Gmail 스코프는 Google이 device flow에서 차단하므로, authorization code flow (localhost redirect)를 지원하는 v0.4.0 이상이 필요하다. v0.3.0 이하에서는 `Invalid device flow scope` 에러가 발생한다.

#### 1. 로그인 상태 확인

```bash
gws-auth status 2>/dev/null && echo "AUTH OK"
```

로그인되어 있지 않으면 **사용자에게** 아래 실행을 요청 (브라우저에서 Google OAuth 동의 1회 필요 — 에이전트가 직접 실행할 수 없음):

```bash
gws-auth login --scope gmail.modify
```

이미 로그인되어 있지만 gmail 스코프가 없으면 재로그인 요청 (기존 스코프도 함께 지정해야 유지됨):

```bash
gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file
```

> **스코프 참고**: `gmail.modify`는 읽기+쓰기+라벨 관리를 포함한다. 읽기 전용이 필요하면 `gmail.readonly`, 발송만 필요하면 `gmail.send`를 사용.

사용 가능한 스코프 확인: `gws-auth scopes`

#### 2. 매 호출 전 토큰 + 프로젝트 주입

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gws-auth token)
export GOOGLE_WORKSPACE_PROJECT_ID="${GOOGLE_WORKSPACE_PROJECT_ID}"
```

## How to call

### Helper commands (recommended)

```bash
# Triage — 읽지 않은 메일 요약
gws gmail +triage
gws gmail +triage --max 10 --query 'from:boss@example.com'
gws gmail +triage --format json --labels

# Read — 메시지 본문 읽기
gws gmail +read --id <MESSAGE_ID>
gws gmail +read --id <MESSAGE_ID> --headers
gws gmail +read --id <MESSAGE_ID> --html

# Send — 메일 발송
gws gmail +send --to alice@example.com --subject 'Hello' --body 'Hi Alice!'
gws gmail +send --to alice@example.com --subject 'Report' --body 'See attached' -a report.pdf
gws gmail +send --to alice@example.com --subject 'Hello' --body '<b>Bold</b> text' --html
gws gmail +send --to alice@example.com --subject 'Draft' --body 'Review this' --draft

# Reply — 답장 (스레딩 자동)
gws gmail +reply --message-id <MESSAGE_ID> --body 'Thanks, got it!'
gws gmail +reply --message-id <MESSAGE_ID> --body 'Looping in Carol' --cc carol@example.com
gws gmail +reply --message-id <MESSAGE_ID> --body 'Draft reply' --draft

# Reply-all — 전체 답장
gws gmail +reply-all --message-id <MESSAGE_ID> --body 'Acknowledged!'

# Forward — 전달 (원본 첨부 포함)
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com --body 'FYI see below'
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com --no-original-attachments

# Watch — 새 메일 실시간 모니터링 (Pub/Sub 필요)
gws gmail +watch --project <GCP_PROJECT_ID> --label-ids INBOX --once
```

### Common options for send/reply/forward

| Option | Description |
|--------|-------------|
| `--to` | 수신자 (comma-separated) |
| `--cc` | CC 수신자 |
| `--bcc` | BCC 수신자 |
| `--from` | send-as 별칭 사용 시 발신자 주소 |
| `-a, --attach` | 파일 첨부 (여러 번 지정 가능, 총 25MB 제한) |
| `--html` | body를 HTML로 처리 |
| `--draft` | 발송 대신 임시보관함에 저장 |
| `--dry-run` | 요청 미리보기 (실제 발송 안 함) |

### Direct API commands

```bash
# List messages
gws gmail users messages list --params '{"userId": "me", "q": "is:unread", "maxResults": 10}'

# Get message
gws gmail users messages get --params '{"userId": "me", "id": "<MESSAGE_ID>", "format": "full"}'

# Trash message
gws gmail users messages trash --params '{"userId": "me", "id": "<MESSAGE_ID>"}'

# Untrash message
gws gmail users messages untrash --params '{"userId": "me", "id": "<MESSAGE_ID>"}'

# Modify labels
gws gmail users messages modify --params '{"userId": "me", "id": "<MESSAGE_ID>"}' \
  --json '{"addLabelIds": ["STARRED"], "removeLabelIds": ["UNREAD"]}'

# Batch modify labels
gws gmail users messages batchModify --params '{"userId": "me"}' \
  --json '{"ids": ["<ID1>", "<ID2>"], "addLabelIds": ["IMPORTANT"]}'

# List labels
gws gmail users labels list --params '{"userId": "me"}'

# Create label
gws gmail users labels create --params '{"userId": "me"}' \
  --json '{"name": "My Label", "labelListVisibility": "labelShow"}'

# List threads
gws gmail users threads list --params '{"userId": "me", "q": "subject:meeting", "maxResults": 5}'

# Get thread (all messages in thread)
gws gmail users threads get --params '{"userId": "me", "id": "<THREAD_ID>"}'

# List drafts
gws gmail users drafts list --params '{"userId": "me"}'

# Get profile
gws gmail users getProfile --params '{"userId": "me"}'
```

## IMPORTANT: Token Optimization

**Combine independent gws calls into a single Bash call with `;`. 토큰은 먼저 한번만 export:**

```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gws-auth token)
echo "=== Inbox ===" ; gws gmail +triage --max 5 2>&1
echo "=== Profile ===" ; gws gmail users getProfile --params '{"userId": "me"}' 2>&1
```

## Discover commands

```bash
# List all gmail subcommands
gws gmail --help

# List message operations
gws gmail users messages --help

# Inspect method signature
gws schema gmail.users.messages.list

# Dry-run (preview request without executing)
gws gmail +send --to test@example.com --subject 'Test' --body 'Test' --dry-run
```

## Common Workflows

### Triage and respond to inbox

1. `gws gmail +triage` -> 읽지 않은 메일 목록 확인
2. `gws gmail +read --id <ID> --headers` -> 관심 메일 본문 읽기
3. `gws gmail +reply --message-id <ID> --body '...'` -> 답장 또는
4. `gws gmail +forward --message-id <ID> --to someone@example.com` -> 전달

### Search and read specific emails

1. `gws gmail users messages list --params '{"userId": "me", "q": "from:alice subject:report"}'` -> 검색
2. `gws gmail +read --id <ID> --headers` -> 본문 읽기

### Send email with attachments

1. `gws gmail +send --to recipient@example.com --subject 'Report' --body 'Please find attached.' -a report.pdf -a data.csv`

### Manage labels

1. `gws gmail users labels list --params '{"userId": "me"}'` -> 라벨 목록
2. `gws gmail users labels create ...` -> 라벨 생성
3. `gws gmail users messages modify ...` -> 메시지에 라벨 적용

### Draft and review before sending

1. `gws gmail +send --to ... --subject ... --body ... --draft` -> 임시보관함에 저장
2. `gws gmail users drafts list --params '{"userId": "me"}'` -> 임시보관 확인
3. `gws gmail users drafts send --params '{"userId": "me"}' --json '{"id": "<DRAFT_ID>"}'` -> 발송

## Notes

- `+triage`, `+read`, `+send`, `+reply`, `+reply-all`, `+forward`는 gws helper 커맨드 (간편 인터페이스)
- `--dry-run` 플래그로 실제 실행 없이 요청 미리보기 가능
- `--page-all` 플래그로 대량 결과 자동 페이지네이션 (NDJSON 출력)
- `--draft` 플래그로 발송 대신 임시보관함에 저장 가능
- Gmail 검색 쿼리는 Gmail 검색창과 동일한 문법 지원 (예: `from:`, `subject:`, `is:unread`, `has:attachment`)
- 첨부파일 총 크기 제한: 25MB
- `+watch`는 GCP Pub/Sub 설정이 필요 (일반 사용에서는 `+triage`로 충분)
