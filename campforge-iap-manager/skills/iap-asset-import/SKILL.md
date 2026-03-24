---
name: iap-asset-import
description: >
  FungibleAssets 및 FungibleItems CSV 임포트.
  Triggers: "에셋 임포트", "아이템 임포트", "fungible import"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
compatibility: Requires gq (graphqurl) CLI and gql-ops skill
---

# IAP Asset Import

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment Variables

```bash
echo $BO_GQL        # GraphQL gateway URL
echo $BO_API_KEY     # API key
```

## When to Use

- FungibleAsset(NCG, Crystal 등) 데이터를 CSV로 임포트할 때
- FungibleItem(소모품 등) 데이터를 CSV로 임포트할 때

## Workflow

1. CSV 파일 읽기 및 내용 확인
2. 환경(environment) 확인 — 미지정 시 질문
3. 임포트 대상 구분 (FungibleAssets / FungibleItems)
4. 임포트 실행:

### FungibleAssets 임포트

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($csvImportRequestInput: CsvImportRequestInput!, $environment: Environment) {
    postApiIapFungibleAssetsImport(csvImportRequestInput: $csvImportRequestInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"csvImportRequestInput":{"csvContent":"<csv>"},"environment":"production"}' -l
```

### FungibleItems 임포트

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($csvImportRequestInput: CsvImportRequestInput!, $environment: Environment) {
    postApiIapFungibleItemsImport(csvImportRequestInput: $csvImportRequestInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"csvImportRequestInput":{"csvContent":"<csv>"},"environment":"production"}' -l
```

5. 결과 확인 및 보고

## Output Format

```
Asset Import Result:
  Type: FungibleAssets / FungibleItems
  Environment: production
  Status: success / failure
  Message: <API response message>
```

## Stop Conditions

- 임포트 성공 → 결과 보고
- CSV 포맷 에러 → 에러 내용 표시, 중단
- API 에러 → gql-ops self-healing 절차
