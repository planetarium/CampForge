---
name: gql-ops
description: >
  Common GraphQL operations with gq (graphqurl) CLI. Provides schema
  introspection, query file validation, self-healing on API changes, and
  query authoring guidance. Activated by domain-specific GQL skills
  (v8-api, 9c-backoffice, etc.) — not intended for direct use.
license: Apache-2.0
metadata:
  author: swen
  version: "0.2"
compatibility: Requires gq (graphqurl) CLI
---

# GQL Operations Skill

Shared knowledge for any skill that talks to a GraphQL API via `gq`.

## Setup

1. **gq CLI**: verify with `which gq`. If missing: `npm i -g graphqurl`
2. **Environment variables** — the calling skill specifies which variables to set
   (endpoint URL, auth credential, skill directory path). Check if set, ask user if not.
3. **Skill directory** — set the variable to the absolute path of the calling skill's
   folder. Query files live in its `queries/` subdirectory.

## Calling conventions

Use the endpoint URL and auth header env vars defined by the calling skill:

```bash
# v8-api example
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/<name>.gql" -j '<variables>' -l

# 9c-backoffice example
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" --queryFile "$BO_SKILL_DIR/queries/<name>.gql" -j '<variables>' -l
```

- Always use `-l` for compact JSON output (fewer tokens).
- Use `--queryFile` for pre-defined queries; use inline `-q` for short mutations.

## Schema introspection

**Do NOT introspect upfront.** Only fetch the schema when a query fails or when
creating a new query file. This avoids wasting tokens on startup.

Use a skill-specific filename to avoid cross-contamination when multiple GQL skills
are active.

**Note:** `gq --introspect` outputs **SDL format** (not JSON). Use `grep` to search
for type/field names in the SDL file. Do not attempt to parse it as JSON.

```bash
# v8-api
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --introspect > /tmp/v8-api-schema.sdl

# 9c-backoffice
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" --introspect > /tmp/9c-backoffice-schema.sdl
```

## Schema validation (on failure only)

**Do NOT validate .gql files upfront.** Trust existing query files and run them
directly. Only introspect and validate when a query actually fails:

1. On GraphQL error, introspect the schema (if not already cached in `/tmp/`).
2. Read the error message:
   - `Cannot query field "X"` — field renamed or removed. Search the schema SDL for the correct name, fix the `.gql` file.
   - `Unknown type "X"` — enum or type renamed. Search the schema SDL for the correct name.
   - `Could not invoke operation` — backend error (auth, server down). Check `statusCode` and `message` in the error extensions for details.
3. Fix the `.gql` file (or inline mutation) based on the schema.
4. Retry the query.

Do NOT retry the same failing query without fixing the query first.
When writing inline mutations, check the schema SDL for the exact mutation name and
response type fields before executing.

## Creating new queries

If the skill's `queries/` directory doesn't have what you need:

1. Introspect the schema (if not already done).
2. Find the relevant type/query in the schema file.
3. Write a `.gql` file selecting only the fields you need.
4. Save to the skill's `queries/` directory for reuse.
