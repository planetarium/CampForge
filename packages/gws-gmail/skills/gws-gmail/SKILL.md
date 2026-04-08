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
compatibility: Requires @campforge/gws-auth skill (^0.1.0). Gmail scopes require the gws-auth CLI (github:planetarium/gws-auth) ≥0.4.0 for authorization code flow.
---

# Gmail Skill (gws CLI)

Authentication, installation, and token setup are handled by the **gws-auth** skill. Before proceeding, load/activate the `@campforge/gws-auth` skill dependency. If not already authenticated, the agent can run `gws-auth login --scope gmail.modify` to start the OAuth flow — the user must complete the browser consent step themselves.

## How to call

### Helper commands (recommended)

```bash
# Triage — summarize unread inbox
gws gmail +triage
gws gmail +triage --max 10 --query 'from:boss@example.com'
gws gmail +triage --format json --labels

# Read — extract message body
gws gmail +read --id <MESSAGE_ID>
gws gmail +read --id <MESSAGE_ID> --headers
gws gmail +read --id <MESSAGE_ID> --html

# Send — send an email
gws gmail +send --to alice@example.com --subject 'Hello' --body 'Hi Alice!'
gws gmail +send --to alice@example.com --subject 'Report' --body 'See attached' -a report.pdf
gws gmail +send --to alice@example.com --subject 'Hello' --body '<b>Bold</b> text' --html
gws gmail +send --to alice@example.com --subject 'Draft' --body 'Review this' --draft

# Reply — reply with automatic threading
gws gmail +reply --message-id <MESSAGE_ID> --body 'Thanks, got it!'
gws gmail +reply --message-id <MESSAGE_ID> --body 'Looping in Carol' --cc carol@example.com
gws gmail +reply --message-id <MESSAGE_ID> --body 'Draft reply' --draft

# Reply-all
gws gmail +reply-all --message-id <MESSAGE_ID> --body 'Acknowledged!'

# Forward — includes original attachments by default
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com --body 'FYI see below'
gws gmail +forward --message-id <MESSAGE_ID> --to dave@example.com --no-original-attachments

# Watch — real-time email monitoring (requires Pub/Sub)
gws gmail +watch --project "<GCP_PROJECT_ID>" --label-ids INBOX --once
```

### Common options for send/reply/forward

| Option | Description |
|--------|-------------|
| `--to` | Recipient(s), comma-separated |
| `--cc` | CC recipient(s) |
| `--bcc` | BCC recipient(s) |
| `--from` | Sender address for send-as aliases |
| `-a, --attach` | Attach a file (repeatable, 25MB total limit) |
| `--html` | Treat body as HTML |
| `--draft` | Save to drafts instead of sending |
| `--dry-run` | Preview request without executing |

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

## Common Workflows

### Triage and respond to inbox

1. `gws gmail +triage` -> list unread messages
2. `gws gmail +read --id <ID> --headers` -> read message body
3. `gws gmail +reply --message-id <ID> --body '...'` -> reply, or
4. `gws gmail +forward --message-id <ID> --to someone@example.com` -> forward

### Search and read specific emails

1. `gws gmail users messages list --params '{"userId": "me", "q": "from:alice subject:report"}'` -> search
2. `gws gmail +read --id <ID> --headers` -> read body

### Send email with attachments

1. `gws gmail +send --to recipient@example.com --subject 'Report' --body 'Please find attached.' -a report.pdf -a data.csv`

### Manage labels

1. `gws gmail users labels list --params '{"userId": "me"}'` -> list labels
2. `gws gmail users labels create ...` -> create label
3. `gws gmail users messages modify ...` -> apply label to message

### Draft and review before sending

1. `gws gmail +send --to ... --subject ... --body ... --draft` -> save to drafts
2. `gws gmail users drafts list --params '{"userId": "me"}'` -> verify draft
3. `gws gmail users drafts send --params '{"userId": "me"}' --json '{"id": "<DRAFT_ID>"}'` -> send draft

## Notes

- `+triage`, `+read`, `+send`, `+reply`, `+reply-all`, `+forward` are gws helper commands (simplified interface)
- `--dry-run` flag previews the HTTP request without executing
- `--page-all` flag auto-paginates large result sets (NDJSON output)
- `--draft` flag saves to drafts instead of sending
- Gmail search query syntax matches the Gmail web search box (e.g., `from:`, `subject:`, `is:unread`, `has:attachment`)
- Total attachment size limit: 25MB
- `+watch` requires GCP Pub/Sub setup (for typical use, `+triage` is sufficient)
