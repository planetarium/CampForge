---
name: v8-api
description: >
  V8 platform admin API operations via GraphQL. Use when asked to manage users,
  grant or query credits, manage verses, game payments, coupons, analytics,
  or comments. Triggers on requests like "give credits to user", "search user",
  "set verse featured", "generate coupons", "find spam comments".
license: Apache-2.0
metadata:
  author: swen
  version: "0.8"
compatibility: Requires gq (graphqurl) CLI and a running GraphQL gateway
---

# V8 API Skill (GraphQL)

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment variables

```bash
echo $V8_GQL        # GraphQL gateway URL (default: https://planetarium-oag.fly.dev/v8-admin/graphql)
echo $V8_SKILL_DIR   # Absolute path to this skill directory
```

If `$V8_GQL` or `$V8_SKILL_DIR` is not set, ask user.

### Authentication

**You MUST run this yourself** before any API call — do NOT ask the user to run it manually:

```bash
eval $(bash "$V8_SKILL_DIR/v8-auth.sh")
```

- If a cached token exists and is valid → instant, no user interaction needed.
- If no valid token → the script starts RFC 8628 device flow:
  1. Prints a **user code** and **URL** to stderr.
  2. Polls for completion (blocks until user authorizes in browser).
  3. **Show the user code and URL to the user** and ask them to open it in their browser.
  4. The script will finish once the user completes browser auth (~30s typical).
  5. Use `timeout 120` if worried about hanging: `eval $(timeout 120 bash "$V8_SKILL_DIR/v8-auth.sh")`

## How to call

```bash
# Read (--queryFile + -j)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/<name>.gql" -j '<json>' -l

# Write (inline -q)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { ... }' -l
```

**Required:**
- Pass variables with **`-j`** (NOT `-v`)
- Always use **`-l`** (compact output)
- Do NOT ls `$V8_SKILL_DIR/queries/` — the table below is the complete list

## IMPORTANT: Token Optimization

**Never run independent queries as separate Bash calls. Always combine them into a single Bash call with `;`:**

```bash
export V8_GQL="..." V8_TOKEN="..." V8_SKILL_DIR="..."
echo "=== Users ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/users-search.gql" -j '{"keyword":"test","limit":5}' -l 2>&1
echo "=== Comments ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"limit":5}' -l 2>&1
echo "=== Verse ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/verse-list.gql" -j '{"limit":5}' -l 2>&1
```

## Queries

`$V8_SKILL_DIR/queries/` file list:

| File | Purpose | `-j` variables |
|------|---------|----------------|
| `users-search.gql` | Search users | `{"keyword":"…","limit":20}` |
| `users-low-balance.gql` | Low balance users | `{"threshold":5,"limit":20}` |
| `comments-list.gql` | List/search comments | `{"limit":50}` or `{"searchType":"…","keyword":"…","filter":"…"}` |
| `verse-list.gql` | List verses | `{"limit":20,"featured":"ONLY"}` |
| `game-payments-list.gql` | List game payments | `{"limit":20}` |
| `game-payment-items-list.gql` | Payment items | `{"gamePaymentId":"<id>","limit":20}` |

`searchType`: `USEREMAIL` / `USERDISPLAYNAME` / `VERSETITLE` / `VERSESHORTID` / `COMMENTCONTENT`
`filter`: `ALL` / `ACTIVE` / `DELETED`

For new queries, see `gql-ops` skill's "Creating new queries".

## Mutations (inline -q)

```bash
# Grant credits (amount in USD)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerCreateAdminCoupon(adminCouponDtoInput: {userUid: "<uid>", amount: 20}) { success transactionId } }' -l

# Delete comments
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerBatchCommentAction(batchCommentActionDtoInput: {commentIds: [1,2,3], action: "delete"}) { processed failed errors } }' -l

# Trigger analytics
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerCalculateQualityScores { success executionTimeMs } }' -l
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerUpdateTrendingScores { success executionTimeMs } }' -l
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerMissionRankCalculation { success executionTimeMs } }' -l
```

## Common Workflows

### Search user + grant credits
1. `--queryFile users-search.gql` -j `{"keyword":"<email>"}` → get `userUid`
2. inline mutation `adminControllerCreateAdminCoupon` with `userUid`, `amount`
3. Re-run search to verify

### Find and remove spam comments
1. `--queryFile comments-list.gql` -j `{"limit":50}` → scan for patterns
2. `--queryFile comments-list.gql` -j `{"searchType":"USEREMAIL","keyword":"<email>","filter":"ALL"}`
3. inline mutation `adminControllerBatchCommentAction` with `commentIds`, `action: "delete"`

## Notes

- Credit amounts are in USD (e.g. `20` = $20)
- See `references/admin-api.md` for REST fallback
