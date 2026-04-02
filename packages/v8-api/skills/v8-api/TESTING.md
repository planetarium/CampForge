# V8 API — Smoke Test Playbook

A playbook for agents to test all V8 Admin API features and report results.

## Prerequisites

1. Load the `/v8-api` skill. It contains call conventions, query files, and mutation examples. Also load the `gql-ops` dependency skill (needed for schema introspection, validation, and self-healing).
2. Set environment variables (`V8_GQL`, `V8_TOKEN`, `V8_SKILL_DIR`). Ask the user for `V8_TOKEN`.

## How to run

Spawn **4 sub-agents in parallel**. Give each agent only the environment variables and the list of features to test. Agents should read the skill docs (SKILL.md) to figure out exact call syntax on their own.

- **Agent 1 — Users**: user search, low-balance users query
- **Agent 2 — Comments**: comments list, search comments by email
- **Agent 3 — Verse + Game Payments**: verse list, featured verse list, game payments list, game payment items list
- **Agent 4 — Mutations**: grant a small credit amount → verify balance change via user search, trigger analytics (quality scores, trending scores, mission ranks). Skip comment deletion (destructive operation).

Within each agent, run independent commands in parallel when possible. After all 4 agents complete, combine results into the report format below.

## Error handling

1. `Cannot query field "X"` — Schema change. Introspect: `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --introspect > /tmp/v8-api-schema.sdl`, then fix the `.gql` file.
2. `Could not invoke operation` — Backend error. Check `statusCode`, `message`, `responseBody` in extensions via curl:
   ```bash
   curl -s -X POST "$V8_GQL" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $V8_TOKEN" \
     -d '{"query":"{ <failed query> }"}' | python3 -m json.tool
   ```
3. Auth error — Check if the JWT has expired by decoding the `exp` claim.

## Report format

After all tests complete, report in this format:

| # | Test | Result | Notes |
|---|------|--------|-------|
| 1 | users-search | PASS/FAIL | record count or error message |
| ... | ... | ... | ... |

End with summary: N passed, N failed, N skipped
