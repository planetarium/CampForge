---
name: openclaw-bot-audit
description: >
  Audit an OpenClaw bot deployed on Fly.io — find the app, wake the machine if
  stopped, download the session JSONL from the persistent volume, and reconstruct
  the conversation (user messages, tool calls, tool results) plus any ephemeral
  working files referenced during the session.
  Triggers on requests like "fly에 떠 있는 봇 어제 뭐했어",
  "openclaw 봇 세션 audit", "봇 세션 로그 보여줘",
  "이 봇이 발행한 tx 뭐있어", "어제 패치한 CSV 복원해줘",
  "what did <bot-name> do yesterday".
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires `flyctl` (authenticated, with access to the target org) and `jq`. Read access to the bot's Fly app + volume is required.
---

# OpenClaw Bot Audit (Fly.io)

OpenClaw bots running on Fly write durable session logs to a persistent volume
mounted at `/data`. This skill walks the standard recovery flow: locate the
app, wake the machine, pull the session JSONL, and parse it.

> ⚠️ **Read-only by default.** This skill never restarts, deploys, or modifies
> the bot. Waking a stopped machine via `fly machine start` is the only state
> change — required so SSH/SFTP works. Do not stop or restart the machine
> after the audit unless the user explicitly asks.

## 0. Prerequisites

```bash
fly auth whoami        # confirm logged in
fly orgs list          # confirm access to the right org
which jq               # required for JSONL parsing
```

If the user only knows part of the bot's name, search:

```bash
fly apps list 2>&1 | grep -i <keyword>
```

OpenClaw bots typically use the image `openclaw/openclaw:<version>`. Confirm
with `fly status -a <app>` if unsure.

## 1. Find the machine

```bash
fly status -a <app>
```

Note the machine ID (e.g. `17813102f23778`), region, and `STATE`. If `STATE`
is `stopped`, wake it:

```bash
fly machine start <machine-id> -a <app>
sleep 8   # let SSH come up
```

## 2. Locate the session files

OpenClaw sessions live on the persistent volume:

| Path | Contents |
|------|----------|
| `/data/agents/main/sessions/*.jsonl` | One file per agent run (`<runId>.jsonl`) |
| `/data/agents/main/sessions/sessions.json` | Index/state |
| `/data/memory/main.sqlite` | Durable agent memory |
| `/data/skills/<name>/` | Installed skills |
| `/data/credentials/` | Channel credentials (telegram allowlist, etc.) |
| `/data/cron/` | Scheduled jobs + run logs (`runs/*.jsonl`) |

`~/.openclaw/workspace/` is **rebuilt on every restart** — never trust it for
historical data. `/tmp` is also wiped on machine restart, so any working
files (CSV, payload dumps) the agent created there are gone unless they were
echoed back into a tool result inside the JSONL.

List recent sessions by mtime:

```bash
fly ssh console -a <app> -C "bash -lc 'ls -lat /data/agents/main/sessions/ | head -20'"
```

Match the user's timeframe against the file mtime. The file name is the
runId; cross-reference with bot logs (`fly logs -a <app> --no-tail`) which
print runIds in lines like `embedded run timeout: runId=<uuid>`.

## 3. Download the session

```bash
fly ssh sftp get -a <app> \
  /data/agents/main/sessions/<runId>.jsonl \
  /tmp/<app>-<runId>.jsonl
```

Files are typically <5 MB. If you need multiple sessions, batch them — every
SFTP invocation establishes a new SSH session.

## 4. JSONL schema cheat sheet

Each line is one record. The first line is session metadata; the rest are
event entries with a stable shape:

```jsonc
// line 1 — session header
{"type":"session","version":3,"id":"<runId>","timestamp":"...","cwd":"..."}

// user input
{"type":"message","timestamp":"...","message":{
  "role":"user",
  "content":[{"type":"text","text":"<user message>"}]
}}

// assistant turn (text + tool calls)
{"type":"message","timestamp":"...","message":{
  "role":"assistant",
  "content":[
    {"type":"text","text":"..."},
    {"type":"toolCall","id":"toolu_...","name":"exec",
     "arguments":{"command":"...","timeout":30}}
  ],
  "model":"claude-...","usage":{...},"stopReason":"toolUse"
}}

// tool execution result
{"type":"message","timestamp":"...","message":{
  "role":"toolResult",
  "toolCallId":"toolu_...",
  "toolName":"exec",
  "content":[{"type":"text","text":"<stdout/stderr>"}]
}}

// other types you may see
{"type":"custom",...}        // hooks, system events
{"type":"summary",...}       // post-compaction summaries (note tokensBefore)
```

Match a `toolCall.id` to its `toolResult.toolCallId` to pair command with
output. Roles inside `message.role`: `user`, `assistant`, `toolResult`
(plus `null` for some custom entries).

## 5. Standard jq recipes

Set once:

```bash
S=/tmp/<app>-<runId>.jsonl
DAY="2026-04-14"   # optional time filter; YYYY-MM-DD or YYYY-MM-DDTHH
```

### User message timeline

```bash
jq -r --arg day "$DAY" '
  select(.timestamp | startswith($day))
  | select(.type=="message" and .message.role=="user")
  | [.timestamp,
     (.message.content
      | if type=="string" then .
        else (map(select(.type=="text")) | map(.text) | join(" | "))
        end)]
  | @tsv
' "$S"
```

### List every tool call (name + first 200 chars of args)

```bash
jq -r --arg day "$DAY" '
  select(.timestamp | startswith($day))
  | select(.type=="message" and .message.role=="assistant")
  | .message.content[]?
  | select(.type=="toolCall")
  | [.timestamp, .id, .name, (.arguments | tostring | .[0:200])]
  | @tsv
' "$S"
```

### Look up a single toolCall + its result by id

```bash
TID=toolu_01TzMphjgUX1NKq4qmDVLEYt
echo "=== command ==="
jq -r --arg id "$TID" '
  select(.type=="message" and .message.role=="assistant")
  | .message.content[]?
  | select(.type=="toolCall" and .id==$id)
  | .arguments.command // (.arguments | tostring)
' "$S"
echo "=== result ==="
jq -r --arg id "$TID" '
  select(.type=="message" and .message.role=="toolResult"
         and .message.toolCallId==$id)
  | .message.content[].text
' "$S"
```

### Extract all transaction IDs (Nine Chronicles, ETH-style hex64)

```bash
jq -r 'select(.type=="message" and .message.role=="toolResult")
       | .message.content[]? | select(.type=="text") | .text' "$S" \
  | grep -oE '"txId":"[0-9a-f]{64}"' | sort -u
```

### Find tool results that mention a substring

```bash
jq -r --arg pat "CollectionSheet" '
  select(.type=="message" and .message.role=="toolResult")
  | .message.content[]? | select(.type=="text")
  | select(.text | contains($pat))
  | .text
' "$S" | head -200
```

### Pair commands containing a pattern with their output

```bash
jq -r --arg pat "table-patch-stage" '
  select(.type=="message" and .message.role=="assistant")
  | .message.content[]?
  | select(.type=="toolCall")
  | select(.arguments.command // "" | test($pat))
  | .id
' "$S" | while read -r tid; do
  echo "--- $tid ---"
  jq -r --arg id "$tid" '
    select(.message.toolCallId==$id)
    | .message.content[].text
  ' "$S" | head -5
done
```

## 6. Recovering ephemeral working files

When the agent wrote intermediate files to `/tmp` (CSVs, payload dumps, JSON
variable files), those are gone after a machine restart. Three recovery
paths, in order of fidelity:

1. **Inline tool arguments** — if the tool call inlined the data
   (`-j '{"tableCsv":"id,..."}'`), the full payload is in the JSONL. Extract
   it from `.arguments.command`.
2. **Echoed tool output** — `head`, `cat`, `wc`, `python3 ... print(...)`
   results land in `toolResult.content[].text`. Even partial output (e.g.
   `head -3`) lets you verify the shape and re-derive from a source.
3. **Original source** — if the data came from a Google Sheet, R2 URL, or
   GitHub, refetch and replay the same transformation pipeline that the
   agent ran (the pipeline itself is preserved as a Bash/Python heredoc
   inside the toolCall command).

When replaying transformations, copy the python/bash heredoc verbatim from
the JSONL — tiny differences (whitespace, sort order, line endings) change
the resulting hash and make chain comparisons fail.

## 7. Cross-checking on-chain artifacts

For Nine Chronicles bots, txIds extracted in §5 can be inspected at:

- Mainnet (Odin): `https://9cscan.com/tx/<txId>`
- Internal (Odin): `https://internal-odin.9cscan.com/tx/<txId>`

Match the txId back to the originating `toolCall.id` to see the exact
`tableName`, `planetId`, and CSV that produced it.

## 8. Cleanup

Don't stop the machine on the user's behalf. If you woke it and the user
wants it parked again, ask first, then:

```bash
fly machine stop <machine-id> -a <app>
```

Local files (`/tmp/<app>-<runId>.jsonl`) can stay — they're useful if the
user follows up with more questions. If sensitive (API keys, tokens),
delete after the audit:

```bash
shred -u /tmp/<app>-<runId>.jsonl 2>/dev/null || rm -f /tmp/<app>-<runId>.jsonl
```

## Notes & gotchas

- **JSON formatting in Bash:** JSONL lines often contain very long single
  lines (>1 MB). Don't `cat` them to terminal; always pipe through `jq`.
- **Token-heavy outputs:** assistant turns include full `usage` and
  `model` fields. Filter to `.message.content` and `.timestamp` whenever
  possible.
- **Time zones:** all timestamps are UTC. Convert when reporting to users.
- **Compaction summaries:** sessions that ran long contain `type=summary`
  entries with `tokensBefore`. Earlier raw turns are still present above
  the summary line — don't assume the summary replaced them.
- **Secrets in commands:** `BO_API_KEY`, `V8_TOKEN`, sheet share URLs and
  similar may appear in plain text inside `toolCall.arguments.command`.
  Mask before pasting into chat or tickets.
- **Multiple sessions per day:** each `openclaw agent run` writes a new
  JSONL. If the user's timeframe spans a restart, you may need two files.
