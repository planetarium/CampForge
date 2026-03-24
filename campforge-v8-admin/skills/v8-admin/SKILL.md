---
name: v8-admin
description: >
  V8 platform admin API operations via GraphQL. Use when asked to manage users,
  grant or query credits, manage verses, game payments, coupons, analytics,
  or comments. Triggers on requests like "give credits to user", "search user",
  "set verse featured", "generate coupons", "find spam comments".
license: Apache-2.0
metadata:
  author: swen
  version: "0.7"
compatibility: Requires gq (graphqurl) CLI and a running GraphQL gateway
---

# V8 Admin API Skill (GraphQL)

**Before proceeding, load the `gql-ops` skill dependency.** It provides schema introspection, validation, and self-healing guidance used by this skill. The `gql-ops` skill must be installed alongside this skill.

## Environment variables

Check if set, ask user if not:

```bash
echo $V8_GQL   # GraphQL gateway URL
echo $V8_TOKEN  # Admin JWT
echo $V8_SKILL_DIR  # Absolute path to this skill directory
```

Defaults:

```bash
export V8_GQL="https://planetarium-oag.fly.dev/v8-admin-test/graphql"
export V8_TOKEN="<ask user for admin JWT>"
export V8_SKILL_DIR="<absolute path to this v8-admin skill directory>"
```

## How to call

Use `gq` with `$V8_GQL` and `$V8_TOKEN`. For reads, use `--queryFile` with `$V8_SKILL_DIR/queries/`. For writes, use inline `-q`. Always use `-l` for compact output.

```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/<name>.gql" -j '<variables>' -l
```

## Queries (use --queryFile)

Pre-defined query files in `queries/`. If a query file doesn't exist for your needs, follow the `gql-ops` skill's "Creating new queries" guidance.

### Users search
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/users-search.gql" -j '{"keyword":"michael","limit":20}' -l
```

### Users low balance
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/users-low-balance.gql" -j '{"threshold":5,"limit":20}' -l
```

### Comments list / search
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"limit":50}' -l
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"searchType":"USEREMAIL","keyword":"foo@bar.com","filter":"ALL"}' -l
```
`searchType` enum values: `USEREMAIL`, `USERDISPLAYNAME`, `VERSETITLE`, `VERSESHORTID`, `COMMENTCONTENT`
`filter` enum values: `ALL`, `ACTIVE`, `DELETED`

### Verse list
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/verse-list.gql" -j '{"limit":20,"featured":"ONLY"}' -l
```

### Game payments list
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/game-payments-list.gql" -j '{"limit":20}' -l
```

### Game payment items list
```bash
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/game-payment-items-list.gql" -j '{"gamePaymentId":"<id>","limit":20}' -l
```

## Mutations (use inline -q)

Short enough to inline:

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
1. `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/users-search.gql" -j '{"keyword":"<email>"}' -l` → get `userUid`
2. `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerCreateAdminCoupon(adminCouponDtoInput: {userUid: "<uid>", amount: 20}) { success transactionId } }' -l`
3. Re-run search to verify

### Find and remove spam comments
1. `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"limit":50}' -l` → scan for suspicious patterns
2. `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"searchType":"USEREMAIL","keyword":"<email>","filter":"ALL"}' -l`
3. `gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { adminControllerBatchCommentAction(batchCommentActionDtoInput: {commentIds: [<ids>], action: "delete"}) { processed failed errors } }' -l`

## API Reference

See `references/admin-api.md` for full REST endpoint details (fallback when GraphQL doesn't cover an edge case).

## Notes

- Credit amounts are in USD (e.g. `20` = $20, internally `20,000,000,000` base units)
- `--queryFile` paths use `$V8_SKILL_DIR` to resolve absolute paths to query files
- Always use `-l` flag for compact output to minimize tokens
- `$V8_TOKEN` and `$V8_GQL` avoid repeating long JWT and URL in every command
