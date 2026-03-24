---
name: iap-image-upload
description: >
  IAP 상품 이미지 업로드.
  Triggers: "이미지 업로드", "상품 이미지", "product image upload"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
compatibility: Requires gq (graphqurl) CLI and gql-ops skill
---

# IAP Image Upload

**Before proceeding, load the `gql-ops` skill dependency.**

## Environment Variables

```bash
echo $BO_GQL        # GraphQL gateway URL
echo $BO_API_KEY     # API key
```

## When to Use

- IAP 상품 이미지를 업로드하거나 교체할 때

## Workflow

1. 이미지 파일 경로 확인
2. 환경(environment) 확인 — 미지정 시 질문
3. 이미지 업로드:

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  -q 'mutation ($apiIapProductsUploadImagesInput: ApiIapProductsUploadImagesInput!, $environment: Environment) {
    postApiIapProductsUploadImages(apiIapProductsUploadImagesInput: $apiIapProductsUploadImagesInput, environment: $environment) {
      success message data
    }
  }' \
  -j '{"apiIapProductsUploadImagesInput":{"images":["<base64 or url>"]},"environment":"production"}' -l
```

4. 업로드 결과 확인

## Output Format

```
Image Upload Result:
  Environment: production
  Status: success / failure
  Message: <API response message>
```

## Stop Conditions

- 업로드 성공 → 결과 보고
- 파일 없음 → 경로 재확인 요청
- API 에러 → gql-ops self-healing 절차
