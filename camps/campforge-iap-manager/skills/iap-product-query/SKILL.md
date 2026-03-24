---
name: iap-product-query
description: >
  IAP 상품 목록 조회 및 검색. 환경별 상품 리스트와 상세 정보를 확인한다.
  Triggers: "IAP 상품 목록", "상품 조회", "product list"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
compatibility: Requires gq (graphqurl) CLI and gql-ops skill
---

# IAP Product Query

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment Variables

Check if set, ask user if not:

```bash
echo $BO_GQL        # GraphQL gateway URL
echo $BO_API_KEY     # API key
```

Defaults:

```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<ask user>"
```

## When to Use

- 유저가 IAP 상품 목록을 보고 싶을 때
- 특정 환경(production/staging)의 상품을 확인할 때
- 상품 데이터 확인 후 임포트/수정 판단이 필요할 때

## Workflow

1. 환경(environment) 확인 — 미지정 시 "어떤 환경에서 조회할까요? (production / staging)" 질문
2. 상품 목록 조회:

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'query ($environment: Environment, $page: Int, $pageSize: Int) {
    paginatedProductResponseApiResponse(environment: $environment, page: $page, pageSize: $pageSize) {
      success message data { items { id name description price categoryId status } total page pageSize }
    }
  }' \
  -j '{"environment":"production","page":1,"pageSize":20}' -l
```

3. 결과를 테이블로 정리하여 표시
4. 페이지가 더 있으면 "다음 페이지를 볼까요?" 질문

## Output Format

| ID | Name | Price | Category | Status |
|----|------|-------|----------|--------|
| ... | ... | ... | ... | ... |

Total: X items (page Y/Z)

## Stop Conditions

- 조회 완료 후 결과 표시
- API 에러 → gql-ops self-healing 절차
- 인증 에러 → API 키 재요청
