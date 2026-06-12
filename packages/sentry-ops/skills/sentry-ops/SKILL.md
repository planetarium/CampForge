---
name: sentry-ops
description: >
  Triage Sentry issues and run Seer root-cause analysis using sentry-cli
  and the official Sentry MCP server (stdio transport, auth-token based —
  no OAuth). Covers token-auth MCP setup, issue/event querying, Seer
  autofix via a direct-API workaround, and manual event ingest with
  send-event. Use when asked to look at a Sentry issue, find what errors
  are firing, get a root-cause analysis / Seer analysis, send a test event
  to Sentry, or wire Sentry up for an agent.
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires `sentry-cli` and a Sentry User Auth Token in `~/.sentryclirc`. MCP setup needs `npx` (Node) and the `claude` CLI. Seer requires the org to have Seer enabled and a token with `event:write`.
---

# sentry-ops Skill

Two complementary surfaces onto the same Sentry data:

- **sentry-cli** — token-based, headless, scriptable. Best for automation,
  event ingest (`send-event`), releases, and quick `for`-loop queries across
  projects. Already trained into the model; ~no schema overhead.
- **Sentry MCP** (`@sentry/mcp-server`, stdio) — richer querying for a human
  next to the agent: natural-language issue search, event aggregation, and
  Seer root-cause analysis.

They do not overlap on writes: MCP writes = issue triage (`update_issue`);
CLI writes = event ingest + release/sourcemap upload. Use both.

## Authentication model

Everything here uses a **User Auth Token**, not OAuth. The token lives in
`~/.sentryclirc`:

```ini
[auth]
token=sntryu_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Verify it and inspect granted scopes (`sentry-cli info` prints the method,
user, and scopes — never the raw token, so it is safe to run as-is):

```bash
sentry-cli info
```

### Required scopes

| Task | Scope needed |
|------|--------------|
| Read issues/events, list projects | `org:read`, `project:read`, `event:read` |
| Triage (`update_issue`: resolve/assign) | `event:write` |
| **Seer root-cause analysis** | **`event:write`** (or `event:admin`) |
| Manage projects | `project:write` |

A read-only token (`event:read` only) returns **HTTP 403** on Seer and on any
issue mutation. Recommended full set for an ops token:
`org:read project:read project:write team:read team:write event:write`.
Issue a new token at `https://<org>.sentry.io/settings/auth-tokens/`.

## Sentry MCP setup (stdio + token)

The remote endpoint (`mcp.sentry.dev`) is OAuth-only. For token/headless use,
register the **stdio** server instead — it reads `SENTRY_ACCESS_TOKEN` from env:

```bash
TOKEN=$(awk -F= '/^token/{gsub(/ /,"",$2);print $2}' ~/.sentryclirc)
claude mcp add sentry -s user \
  -e SENTRY_ACCESS_TOKEN="$TOKEN" \
  -e SENTRY_HOST=sentry.io \
  -- npx -y @sentry/mcp-server@latest
claude mcp list | grep sentry   # expect: ✔ Connected
```

Notes:
- The token is baked into `~/.claude.json` at registration time. After rotating
  the token, **re-register** (`claude mcp remove sentry -s user` then add) — an
  already-running session keeps the old token until restarted.
- New MCP tools only activate on the **next** Claude Code session. After adding,
  restart before expecting `mcp__sentry__*` tools.

Once active, the useful tools are `find_projects`, `search_issues`,
`search_events`, `get_sentry_resource`, `update_issue`, and
`analyze_issue_with_seer` (see the Seer caveat below).

## Querying issues

### Via MCP (preferred for triage)

- `search_issues(organizationSlug, query, sort, limit)` — natural language or
  Sentry syntax (`is:unresolved level:error firstSeen:-24h`). **No boolean
  `OR`/`AND`** in the query string — the API rejects it (HTTP 400). Pass an
  empty query to list everything regardless of status.
- `search_events(...)` — for counts/aggregations and individual events with
  timestamps (datasets: errors, logs, spans, metrics, profiles, replays).
- `find_projects(organizationSlug)` — list projects / resolve slugs.

### Via sentry-cli (headless / scripting)

`sentry-cli` needs an org slug every call — pass `--org` or export `SENTRY_ORG`.

```bash
export SENTRY_ORG=<org-slug>
sentry-cli projects list
for p in <proj-a> <proj-b>; do
  echo "== $p =="; sentry-cli issues list -p "$p"
done
```

Known CLI quirk: on some versions `sentry-cli organizations list` fails with
`missing field requireEmailVerification` (CLI/server schema drift). Use
`projects list` with an explicit org, or the MCP `find_projects`, instead.

## Seer root-cause analysis

`analyze_issue_with_seer` is the headline capability — root cause with file
locations, line numbers, and concrete code fixes.

### ⚠️ Known bug: MCP tool can't read completed runs

As of `@sentry/mcp-server` 0.36.0, `analyze_issue_with_seer` triggers the run
but throws on reading the result:

```
ZodError: Failed to validate keys: autofix.status
```

The Sentry API returns a **lowercase** status (`completed`) while the MCP's
`AutofixStatusSchema` only accepts the legacy **uppercase** enum (`COMPLETED`).
Tracked upstream as getsentry/sentry-mcp **#1064** (closed → fix stack #963 +
#966, still draft/unmerged → not yet released). Auth/permissions are unrelated;
this is purely a client schema mismatch.

### Workaround: drive Seer over the API directly

This needs the issue's **numeric** ID (from `sentry-cli issues list`, the
`Issue ID` column — not the short `PROJECT-123` form).

```bash
TOKEN=$(awk -F= '/^token/{gsub(/ /,"",$2);print $2}' ~/.sentryclirc)
ORG=<org-slug>; ISSUE_ID=<numeric-issue-id>

# 1. Start (or reuse) a Seer run — HTTP 202 on success
curl -s -X POST \
  "https://sentry.io/api/0/organizations/$ORG/issues/$ISSUE_ID/autofix/" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'

# 2. Poll the result (~2-5 min; status: processing -> completed)
curl -s "https://sentry.io/api/0/organizations/$ORG/issues/$ISSUE_ID/autofix/" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; a=json.load(sys.stdin).get('autofix') or {}; \
print('status:', a.get('status')); \
items=a.get('steps') or a.get('blocks') or []; \
[print('-', (it.get('key') or (it.get('metadata') or {}).get('step') or it.get('type') or '?'), it.get('status') or '') for it in items]"
```

The terminal `status` field is the load-bearing part. The per-item line
handles both autofix response shapes: the legacy `steps[]` (with `key`) and
the newer explorer-mode `blocks[]` (with `metadata.step`) — the live API
currently returns `blocks[]`, so a parser hardcoded to `steps[]` prints
nothing per item even though the run succeeded.

(`results are cached` — re-polling a completed run returns instantly.)
Alternatively, open the issue's Seer panel in the Sentry web UI.

Once #1064's fix is released, drop the workaround: clear the npx cache so the
new server is pulled, then the MCP tool works directly:

```bash
rm -rf ~/.npm/_npx/*/node_modules/@sentry/mcp-server   # force refetch
```

## Sending events (ingest)

Ingest is **DSN-based**, not token-based — `send-event` needs `SENTRY_DSN`
(per project), not the auth token.

```bash
export SENTRY_DSN="https://<key>@oXXXX.ingest.sentry.io/<project_id>"
sentry-cli send-event -m "test event" -l info -t env:dev -e detail:foo
```

Supports `-l` level, `-t key:value` tags, `-e` extra, `-u` user, `-f`
fingerprint, and `--logfile` (last 100 lines as breadcrumbs). Find or create a
project DSN via the MCP `find_dsns` / `create_dsn` tools, or in
`https://<org>.sentry.io/settings/projects/<project>/keys/`.

## Common pitfalls

- **HTTP 403 on Seer or `update_issue`** → token lacks `event:write`. Issue a
  new token with the full scope set and re-register the MCP server.
- **403 persists after rotating the token** → the running session's MCP
  subprocess still holds the old token. Re-register and restart Claude Code.
- **`mcp__sentry__*` tools missing** → server was added mid-session; restart.
- **`ZodError: autofix.status`** → the #1064 Seer bug; use the curl workaround.
- **`Boolean statements ... not supported`** → remove `OR`/`AND` from
  `search_issues` query; split into separate calls or drop the status filter.
- **`organizations list` JSON parse error** → CLI/server drift; use
  `projects list --org <slug>` or MCP `find_projects`.
- **`DSN missing`** → `send-event` needs `SENTRY_DSN`, not the auth token.
