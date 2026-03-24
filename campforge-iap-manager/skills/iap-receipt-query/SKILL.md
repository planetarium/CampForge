---
name: iap-receipt-query
description: >
  IAP 영수증 조회 및 검색. agentAddr, orderId, store, 날짜 등으로 필터링.
  Triggers: "영수증 조회", "구매 내역", "receipt search", "결제 확인"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
compatibility: Requires gq (graphqurl) CLI and gql-ops skill
---

# IAP Receipt Query

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment Variables

```bash
echo $BO_GQL        # GraphQL gateway URL
echo $BO_API_KEY     # API key
```

## When to Use

- 특정 유저의 구매 내역을 확인할 때
- orderId로 영수증을 추적할 때
- 특정 기간/스토어의 구매 통계가 필요할 때

## Workflow

1. 검색 조건 확인 — 유저가 제공한 정보에서 추출:

| 파라미터 | 설명 | 예시 |
|----------|------|------|
| `environment` | 환경 | production |
| `agentAddr` | 에이전트 주소 | 0x... |
| `orderId` | 주문 ID | |
| `appleOrderId` | Apple 주문 ID | |
| `planetId` | 행성 ID | 0x100000000000 |
| `store` | 스토어 (0: Apple, 1: Google) | |
| `status` | 결제 상태 | |
| `startDate` / `endDate` | 날짜 범위 | 2024-01-01 |

2. 영수증 조회:

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'query ($environment: Environment, $agentAddr: String, $orderId: String, $store: Int, $status: Int, $startDate: String, $endDate: String, $page: Int, $pageSize: Int, $planetId: String, $appleOrderId: String) {
    receiptSearchResponseApiResponse(environment: $environment, agentAddr: $agentAddr, orderId: $orderId, store: $store, status: $status, startDate: $startDate, endDate: $endDate, page: $page, pageSize: $pageSize, planetId: $planetId, appleOrderId: $appleOrderId) {
      success message data { items { orderId agentAddr productId store status createdAt } total page pageSize }
    }
  }' \
  -j '{"environment":"production","agentAddr":"0x...","page":1,"pageSize":20}' -l
```

3. 결과를 테이블로 정리

## Output Format

| OrderId | Agent | Product | Store | Status | Date |
|---------|-------|---------|-------|--------|------|
| ... | 0x... | ... | Apple | ... | ... |

Total: X receipts (page Y/Z)

## Stop Conditions

- 조회 완료 후 결과 표시
- 검색 조건 부족 → 필요한 조건 질문
- API 에러 → gql-ops self-healing 절차
