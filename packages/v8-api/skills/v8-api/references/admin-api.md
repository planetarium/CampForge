# V8 Admin API Reference

Auth: `Authorization: Bearer <token>` (JWT)

Environments:
- Production: `https://v8-meme-api.verse8.io`
- Test: `https://v8api.tests.mothership-pla.net`
- Local dev: `https://<ngrok-url>` (changes per session)

---

## User Management

### GET /v1/admin/users/search
Search users by email, name, or handle.

Query params:
- `keyword` (required): email / name / handle
- `page` (default: 1)
- `limit` (default: 20)

Response includes: `userUid`, `name`, `email`, `handle`, `credits`, `creditInUSD`, `isSeller`

---

### GET /v1/admin/users/low-balance-details
Get users with low credit balance.

Query params:
- `threshold`: USD threshold (default: 5)
- `page`, `limit`

---

### POST /v1/admin/users/set-seller
Set/remove VX Shop seller status. (VX Shop is a distinct in-platform marketplace feature, separate from the V8 platform name.)

```json
{ "userUid": "100001", "isSeller": true }
```

---

### POST /v1/admin/users/update-tier
Update user tier manually. (No body schema exposed)

---

### POST /v1/admin/users/ban
Batch-ban abusive users. In one transaction: creates an active `BLOCKED` restriction (already-blocked users skipped), soft-deletes the users' comments, privatizes their verses (`isPublic=false, isListed=false`), and busts the affected verse/comment caches so content disappears immediately.

Targets by `userUids` and/or `emails` (at least one required). Emails resolve via `user.email` (case-sensitive); only real users are acted on — unknown ids come back in `unmatchedUserUids` / `unmatchedEmails`.

```json
{ "userUids": ["266340", "266341"], "emails": ["abuser@example.com"], "memo": "Abusive activity", "reason": null }
```

- `memo` (optional, default `"Abusive activity"`), `reason` (optional, shown to the user on login/action)
- Response: `{ success, requestedCount, restrictionsCreated, skippedCount, skippedUserUids, commentsDeleted, versesPrivatized, unmatchedUserUids, unmatchedEmails }`
- Enforcement is automatic: a `BLOCKED` user is blocked at login and on captcha-guarded actions.

---

### POST /v1/admin/users/unban
Batch-unban. Marks the active `BLOCKED` restriction resolved. Does **not** restore soft-deleted comments or privatized verses (that stays a separate manual step).

```json
{ "userUids": ["266340"], "emails": ["abuser@example.com"] }
```

- Response: `{ success, requestedCount, restrictionsResolved, skippedCount, skippedUserUids, unmatchedUserUids, unmatchedEmails }`

---

### GET /v1/admin/users/{userUid}/events
Get credit events for a specific user. Query: `page`, `limit`, `eventType` (`CreditEventType` enum).

---

## Credits

### POST /v1/admin/credits/coupon
Give credits to a user directly.

```json
{ "userUid": "100001", "amount": 20 }
```

- `amount`: in USD (e.g. 20 = $20 = 20,000,000,000 credits internally)
- Response: `{ success, transactionId, couponApplied }`

---

### POST /v1/admin/coupon/generate
Generate redeemable coupon codes (bulk).

```json
{ "amount": 10, "count": 100 }
```

- `amount`: USD per coupon
- `count`: 1–1000
- Response: `{ codes: [...], count }`

---

### POST /v1/admin/credits/expire-all
Batch expire (zero out) credits for a list of users. **Destructive / irreversible.** Max 1000 UIDs per request, processed in concurrent batches of 20; partial success is allowed.

```json
{ "userUids": ["100001", "100002"] }
```

- Response: `{ success, failed, failedUids, executionTimeMs }` (`success`/`failed` are counts)

---

## Verse Management

### GET /v1/admin/verse
Get all verses including private ones.

Query params: `category`, `page`, `limit`, `featured`, `sortBy`, `tag`, `excludeHidden`

---

### GET /v1/admin/verse/search
Search verses by keyword (includes private).

Query params: `keyword` (required), `limit`, `page`

---

### GET /v1/admin/verse/{verseId}
Get single verse by verseId or shortId (includes private).

---

### POST /v1/admin/verse/{verseId}
Update any verse (admin-only fields available).

Key admin-only fields in `VerseUpdateDto`:
- `featured`: boolean
- `mobileFeatured`: boolean
- `isHiddenFromRecommendation`: boolean
- `showcase`: boolean
- `isFitToSpin`: boolean
- `collection`: array (0=Multiplayer, 1=Educational, 2=Story-Driven, 3=3D, 4=Deep Gameplay)
- `visibility`: `public` | `unlisted` | `private`
- `colors`: `{ primary, secondary, tertiary, quaternary }`

> ⚠️ **GraphQL response is opaque.** The GraphQL counterpart `adminControllerAdminUpdateVerse` returns `null` regardless of whether the update was applied — the response shape on silent failure is byte-identical to success. Do **not** infer success from the mutation response (grep, error-envelope absence, exit code). Re-fetch the verse and compare the target fields. See `SKILL.md` → "Opaque-response mutations" and "Bulk mutations" for the required pattern.

---

## Game Payments

### GET /v1/admin/game-payments
List game payments. Query: `page`, `limit`, `status`

### POST /v1/admin/game-payments
Create game payment.
```json
{ "name": "My Payment", "description": "...", "metadata": {}, "status": "active" }
```

### PUT /v1/admin/game-payments/{id}
Update game payment.

### POST /v1/admin/game-payments/{gamePaymentId}/game-payment-items
Create item in a game payment.
```json
{
  "name": "Magic Sword",
  "description": "...",
  "creditPrice": "10000000000",
  "isUnlimitedStock": false,
  "stock": 50,
  "imageUrl": "https://...",
  "status": "active"
}
```
- `creditPrice`: base units (1 USD = 1,000,000,000 credits)

### PUT /v1/admin/game-payments/{gamePaymentId}/game-payment-items/{id}
Update game payment item.

---

## Analytics

### POST /v1/admin/analytics/calculate-quality-scores
Trigger quality score recalculation (Q, Q_final, Rising Score, Hot New Score).

### POST /v1/admin/analytics/update-trending-scores
Trigger trending score update.

---

## Comments

### GET /v1/admin/comments
Get all comments. Query: `page`, `limit`, `searchType`, `keyword`, `filter` (all|active|deleted)

### POST /v1/admin/comments/batch-action
Batch delete/restore comments.
```json
{ "commentIds": [1, 2, 3], "action": "delete" }
```

### POST /v1/admin/comments/recalculate-scores
Recalculate comment scores.

---

## Missions

### POST /v1/admin/missions/calculate-ranks
Trigger creator mission rank calculation.

---

## Misc

### POST /v1/admin/verse-tags/recalculate-counts
Recalculate tag usage counts.

### POST /v1/admin/verse/recalculate-game-sessions
Recalculate game session counts.

---

## Verse Review

Review-queue moderation (controller prefix `v1/admin/verse`).

### GET /v1/admin/verse/review/counts
Per-`reviewStatus` verse counts for the review-queue tab badges (non-deleted verses).

### GET /v1/admin/verse/{verseId}/review-history
Past admin review decisions for a verse (rejection / action-required reasons across versions), newest first.

### POST /v1/admin/verse/{verseId}/review
Apply an admin review decision to a verse.

```json
{ "decision": "approve", "reviewerNote": "" }
```

- `decision`: `approve` | `action-required` | `reject` | `public-review` | `private-review`
- `reviewerNote` (optional): shown to the creator and stored on the release-note audit row

### POST /v1/admin/verse/{verseId}/ai-review
Record an AI first-pass review result onto the latest release note (admin-only display fields; does **not** change `reviewStatus` / decision / reviewerNote). Only allowed while the verse is in `PRIVATE_REVIEW` / `PUBLIC_REVIEW` (else 409).

---

## Selections

Curated home selections (controller prefix `v1/admin/selections`; `{name}` is a `SelectionName` enum value).

### GET /v1/admin/selections
List all selections (metadata only).

### GET /v1/admin/selections/{name}
Get a selection with items (admin view; includes inactive items).

### POST /v1/admin/selections/{name}/items
Append a new item (verse or banner) to a selection.

```json
{ "type": "verse", "verseId": 123, "displayOrder": 1000, "isActive": true }
```

- `type`: `verse` | `banner`. Banner items use `title` / `description` / `imageUrl` / `squareImageUrl` / `videoUrl` / `ctaUrl` / `ctaLabel` / `startTime` / `endTime` instead of `verseId`.

### PATCH /v1/admin/selections/{name}/items/{id}
Update a selection item (banner payload / `isActive` / scheduling).

### DELETE /v1/admin/selections/{name}/items/{id}
Remove an item from a selection.

### PUT /v1/admin/selections/{name}/order
Bulk reorder. Body: `{ "itemIds": [3, 1, 2] }` in desired order (server assigns `displayOrder = (index+1)*1000`).

---

## System Tags

Attach/detach internal system tags on a verse (controller prefix `v1/admin/verses`; `{id}` is the numeric verse id).

### POST /v1/admin/verses/{id}/system-tags
Attach a system tag (e.g. `__MSU`) to a verse. Tag must start with the system-tag prefix (`__`).

```json
{ "tag": "__MSU" }
```

### DELETE /v1/admin/verses/{id}/system-tags/{tagName}
Detach a system tag from a verse.

---

## Push Notifications

### GET /v1/admin/push/logs
Get push notification campaign logs. Query: `page`, `limit`.

### GET /v1/admin/push/rules
Get all push notification rules (3 fixed types).

### PUT /v1/admin/push/rules/{id}
Update a push rule (title, body, url, params, isActive).

```json
{ "title": "...", "body": "...", "url": "/{{verseId}}", "params": {}, "isActive": true }
```

### POST /v1/admin/push/rules/{id}/send
Manually trigger a push rule. For game-specific rules, pass `verseId` in `params`.

```json
{ "params": { "verseId": "abc123" } }
```
