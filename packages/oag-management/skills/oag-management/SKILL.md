---
name: oag-management
description: >
  OAG (OpenAPI-to-GraphQL Gateway) runtime management via REST API.
  Use when asked to add, remove, update, or list gateway APIs,
  manage API keys, or reload schemas.
  Triggers on requests like "add API to gateway", "list OAG APIs",
  "reload schema", "create API key", "remove API from gateway".
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires curl. Gateway must be running with MASTER_KEY configured.
---

# OAG Management Skill (REST API)

## Environment variables

```bash
echo $OAG_URL       # Gateway base URL (default: https://planetarium-oag.fly.dev)
echo $OAG_API_KEY   # API key (full or master)
```

If not set, ask user. For key management operations, a master key is required.

Defaults:

```bash
export OAG_URL="https://planetarium-oag.fly.dev"
export OAG_API_KEY="<ask user for API key>"
```

## Authentication

All `/admin/*` endpoints require `Authorization: Bearer <key>` header.

| Key type | How to obtain | Permissions |
|----------|--------------|-------------|
| master | `MASTER_KEY` env var on Fly.io (ask infra admin) | Everything (API CRUD + key management) |
| full | Issued via `POST /admin/keys` with master key | API CRUD + schema reload |
| readonly | Issued via `POST /admin/keys` with master key | `GET /admin/apis` only |

Data plane endpoints (`POST /:api/graphql`) require no authentication.

## How to call

```bash
# GET
curl -s -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/<path>" | python3 -m json.tool

# POST/PUT with body
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '<json>' "$OAG_URL/<path>"

# DELETE
curl -s -X DELETE -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/<path>"
```

**Token optimization:** combine independent calls in a single Bash invocation with `;`.

## API Management

### List all APIs

```bash
curl -s -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/admin/apis"
```

Response: `[{"name":"v8-admin","url":"https://...","spec_path":"/api-docs-json"}, ...]`

### Get single API

```bash
curl -s -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/admin/apis/<name>"
```

### Add API

Requires `full` or `master` key. The gateway validates by fetching the OpenAPI spec and building a GraphQL schema before saving.

```bash
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"my-api","url":"https://api.example.com","specPath":"/api-docs-json"}' \
  "$OAG_URL/admin/apis"
```

- `name` (required): unique identifier for the API
- `url` (required): base URL of the upstream API
- `specPath` (optional, default `/api-docs-json`): path to OpenAPI spec (can be full URL)

Response: `{"status":"ok","name":"my-api"}` (201) or `{"error":"..."}` (400 if spec fetch/schema build fails)

After adding, the API is immediately available at `POST /$OAG_URL/<name>/graphql`.

### Update API

```bash
curl -s -X PUT -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"url":"https://new-api.example.com","specPath":"/swagger/v1/swagger.json"}' \
  "$OAG_URL/admin/apis/<name>"
```

### Delete API

```bash
curl -s -X DELETE -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/admin/apis/<name>"
```

## Schema Reload

Reload rebuilds the GraphQL schema from the upstream OpenAPI spec without changing config. Use when the upstream API has been updated.

```bash
# Reload single API
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/<name>/reload"

# Reload all APIs
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/reload"
```

## Key Management (master key only)

### List keys

Keys are masked in the response (first 8 chars + `...`).

```bash
curl -s -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/admin/keys"
```

Response: `[{"key":"171ecfc3...","name":"my-skill","role":"full","created_at":"2026-04-09 08:58:55"}, ...]`

### Create key

```bash
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"my-skill","role":"full"}' \
  "$OAG_URL/admin/keys"
```

- `name` (required): label for the key (e.g. "campforge-skill", "monitoring")
- `role` (optional, default `full`): `full` or `readonly`

Response includes the full key — **save it immediately**, it won't be shown again.

### Delete key

```bash
curl -s -X DELETE -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/admin/keys/<key>"
```

## Common Workflows

### Add a new upstream API to the gateway

```bash
# 1. Add the API (validates spec + builds schema)
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"new-service","url":"https://new-service.example.com","specPath":"/api-docs-json"}' \
  "$OAG_URL/admin/apis"

# 2. Verify it's queryable
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}' \
  "$OAG_URL/new-service/graphql"
```

### Refresh schemas after upstream API update

```bash
# Reload specific API
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/v8-admin/reload"

# Or reload all
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" "$OAG_URL/reload"
```

### Issue a read-only key for monitoring

```bash
# Create readonly key (master key required)
curl -s -X POST -H "Authorization: Bearer $OAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"monitoring-dashboard","role":"readonly"}' \
  "$OAG_URL/admin/keys"
```

## Error Responses

| Status | Meaning |
|--------|---------|
| 400 | Bad request — missing fields or spec fetch/schema build failed |
| 401 | No key or invalid key |
| 403 | Key role insufficient (e.g. readonly trying to POST) |
| 404 | API or key not found |
| 500 | No config store (server misconfigured) |

## Notes

- Adding/updating an API triggers a live spec fetch and schema build. If the upstream is down or the spec is invalid, the operation fails with 400 and nothing is saved.
- The data plane (`/:api/graphql`) is unauthenticated — anyone can query. Only management endpoints require auth.
- Config is persisted in SQLite on a Fly Volume. Changes survive restarts.
- The gateway supports `auto_stop_machines = suspend` on Fly.io for fast cold starts (~1s from suspend vs ~8s from stop).
