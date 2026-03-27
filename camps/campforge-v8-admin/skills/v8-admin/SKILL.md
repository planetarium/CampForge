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
  version: "0.8"
compatibility: Requires gq (graphqurl) CLI and a running GraphQL gateway
---

# V8 Admin API Skill (GraphQL)

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment variables

Check if set, ask user if not:

```bash
echo $V8_GQL        # GraphQL gateway URL (default: https://planetarium-oag.fly.dev/v8-admin-test/graphql)
echo $V8_TOKEN       # Admin JWT
echo $V8_SKILL_DIR   # Absolute path to this skill directory
```

## How to call

```bash
# 읽기 (--queryFile + -j)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/<name>.gql" -j '<json>' -l

# 쓰기 (inline -q)
gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" -q 'mutation { ... }' -l
```

**필수:**
- 변수는 반드시 **`-j`** 로 전달 (`-v` 아님)
- 항상 **`-l`** 사용 (compact output)
- `$V8_SKILL_DIR/queries/` 아래 파일을 ls 하지 않는다 — 아래 테이블이 전부

## IMPORTANT: Token Optimization

**독립적인 쿼리는 절대 개별 Bash 호출하지 않는다. 반드시 하나의 Bash 호출에 `;`로 합쳐서 실행한다:**

```bash
export V8_GQL="..." V8_TOKEN="..." V8_SKILL_DIR="..."
echo "=== Users ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/users-search.gql" -j '{"keyword":"test","limit":5}' -l 2>&1
echo "=== Comments ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/comments-list.gql" -j '{"limit":5}' -l 2>&1
echo "=== Verse ===" ; gq $V8_GQL -H "Authorization: Bearer $V8_TOKEN" --queryFile "$V8_SKILL_DIR/queries/verse-list.gql" -j '{"limit":5}' -l 2>&1
```

## Queries

`$V8_SKILL_DIR/queries/` 파일 목록:

| 파일 | 용도 | `-j` 변수 |
|------|------|-----------|
| `users-search.gql` | 유저 검색 | `{"keyword":"…","limit":20}` |
| `users-low-balance.gql` | 저잔액 유저 | `{"threshold":5,"limit":20}` |
| `comments-list.gql` | 댓글 목록/검색 | `{"limit":50}` 또는 `{"searchType":"…","keyword":"…","filter":"…"}` |
| `verse-list.gql` | 버스 목록 | `{"limit":20,"featured":"ONLY"}` |
| `game-payments-list.gql` | 게임 결제 목록 | `{"limit":20}` |
| `game-payment-items-list.gql` | 결제 아이템 | `{"gamePaymentId":"<id>","limit":20}` |

`searchType`: `USEREMAIL` / `USERDISPLAYNAME` / `VERSETITLE` / `VERSESHORTID` / `COMMENTCONTENT`
`filter`: `ALL` / `ACTIVE` / `DELETED`

새 쿼리가 필요하면 `gql-ops` 스킬의 "Creating new queries" 참고.

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
