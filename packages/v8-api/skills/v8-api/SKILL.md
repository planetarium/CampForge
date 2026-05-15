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

# Update a verse's admin-only fields (visibility, isHiddenFromRecommendation, allowRemix, featured, ...)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerAdminUpdateVerse(verseId: "<verseId>", verseUpdateDtoInput: {visibility: UNLISTED, isHiddenFromRecommendation: true, allowRemix: false}) }' -l

# Trigger analytics
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerCalculateQualityScores { success executionTimeMs } }' -l
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerUpdateTrendingScores { success executionTimeMs } }' -l
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerTriggerMissionRankCalculation { success executionTimeMs } }' -l
```

### ⚠️ Opaque-response mutations

Some admin mutations — notably `adminControllerAdminUpdateVerse` — are typed as nullable scalars and return `{"data":{"<field>":null}}` **regardless of whether the change was applied**. The response shape on a silent failure is byte-identical to the response on a successful application.

Consequences for any code or ad-hoc script that calls these:

- **Never** infer success by grepping the response for the field name. Substring matches like `grep '"adminControllerAdminUpdateVerse"'` pass on every call, including silent failures, and will report `failed: 0` for runs where nothing was applied.
- **Never** count `success` as "the mutation returned without an error envelope". A null payload is the normal return on success, so absence of `errors` carries no signal either.
- **The only valid success check is a re-fetch.** Issue an admin verse query right after the mutation and compare the intended fields (`visibility`, `isHiddenFromRecommendation`, `allowRemix`, etc.) against the payload you sent. If they don't match, treat the call as failed and retry — do not trust the mutation response.

This rule applies to any mutation whose return type is a nullable scalar (`String`, `Boolean`, etc.) rather than a structured `{ success, ... }` object. When in doubt, re-fetch.

## Common Workflows

### Search user + grant credits
1. `--queryFile users-search.gql` -j `{"keyword":"<email>"}` → get `userUid`
2. inline mutation `adminControllerCreateAdminCoupon` with `userUid`, `amount`
3. Re-run search to verify

### Find and remove spam comments
1. `--queryFile comments-list.gql` -j `{"limit":50}` → scan for patterns
2. `--queryFile comments-list.gql` -j `{"searchType":"USEREMAIL","keyword":"<email>","filter":"ALL"}`
3. inline mutation `adminControllerBatchCommentAction` with `commentIds`, `action: "delete"`

## Bulk mutations (multi-target writes)

When applying the same admin mutation across many targets (verses, users, comments), do **not** write an ad-hoc one-shot loop that infers success from the mutation response. See "Opaque-response mutations" above — for several admin mutations the response is null whether the change was applied or not, and a naive loop will report `failed: 0` for a run where most targets were silently skipped.

Use this structure instead:

1. **Batch.** Chunk the target list (e.g. 100 per batch). Do not fire thousands of mutations as one tight sequential loop with no checkpoints. Long unbroken loops also make token expiry mid-run a silent failure mode rather than an obvious one.
2. **Refresh the token at batch boundaries.** If `$V8_TOKEN` is close to expiry, re-run `eval $(bash "$V8_SKILL_DIR/v8-auth.sh")` between batches. A run that started with a fresh token can still hit auth-induced silent failures partway through a long loop.
3. **Verify by re-fetch, not by mutation response.** After each mutation (or at minimum a per-batch sample), query the target with an admin verse / user / comment read and confirm the intended fields are set to the intended values. `grep`, exit codes, and "the mutation returned without an error" are not evidence of application.
4. **Count what was verified, not what was called.** When reporting back to the user, distinguish "calls issued" from "verified applied". `failed: 0` from a loop, on its own, is misleading — it only means the calls went out.
5. **Sanity-check the per-target distribution after each batch.** Silent failures tend to cluster (e.g. all of user A's verses applied, none of user B's). If the per-target applied rate suddenly drops to near-zero, stop the run and investigate — do not keep going on the assumption that subsequent batches will recover.

If any batch fails verification, stop and report. Keep a list of unverified target IDs so the run can be resumed against the unapplied subset rather than re-running the whole input list.

## Notes

- Credit amounts are in USD (e.g. `20` = $20)
- See `references/admin-api.md` for REST fallback
