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
