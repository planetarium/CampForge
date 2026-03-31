---
name: iap-product-import
description: >
  IAP 상품, 카테고리, 가격 CSV 임포트.
  Triggers: "상품 임포트", "CSV 임포트", "가격 업데이트", "product import"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
compatibility: Requires gq (graphqurl) CLI and gql-ops skill
---

# IAP Product Import

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment Variables

```bash
echo $BO_GQL        # GraphQL gateway URL
echo $BO_API_KEY     # API key
```

## When to Use

- CSV 파일로 상품 데이터를 일괄 임포트할 때
- 카테고리 구조를 업데이트할 때
- 가격 정보를 일괄 변경할 때

## Workflow

1. CSV 파일 읽기 및 내용 확인
2. 환경(environment) 확인 — 미지정 시 질문
3. 임포트 대상 확인 (상품 / 카테고리 / 가격)
4. **가격 변경이 포함된 경우 반드시 이중 확인**: 변경 내용을 보여주고 "이대로 진행할까요?" 질문
5. 임포트 실행:

### 상품 임포트

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($csvImportRequestInput: CsvImportRequestInput!, $environment: Environment) {
    postApiIapProductsImport(csvImportRequestInput: $csvImportRequestInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"csvImportRequestInput":{"csvContent":"<csv>"},"environment":"production"}' -l
```

### 카테고리 임포트

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($csvImportRequestInput: CsvImportRequestInput!, $environment: Environment) {
    postApiIapProductCategoriesImport(csvImportRequestInput: $csvImportRequestInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"csvImportRequestInput":{"csvContent":"<csv>"},"environment":"production"}' -l
```

### 가격 임포트

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($csvImportRequestInput: CsvImportRequestInput!, $environment: Environment) {
    postApiIapPricesImport(csvImportRequestInput: $csvImportRequestInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"csvImportRequestInput":{"csvContent":"<csv>"},"environment":"production"}' -l
```

6. 결과 확인 및 보고

## Output Format

```
Import Result:
  Type: products / categories / prices
  Environment: production
  Status: success / failure
  Message: <API response message>
```

## Stop Conditions

- 임포트 성공 → 결과 보고
- CSV 포맷 에러 → 에러 내용 표시, 중단
- **가격 변경 확인 거부 → 즉시 중단**
- API 에러 → gql-ops self-healing 절차
