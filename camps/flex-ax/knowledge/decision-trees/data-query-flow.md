# 데이터 조회 흐름

```
$FLEX_HR_AGENT_URL 가 비어있는가? → 기본값(https://flex-hr-10780.fly.dev) 사용 후 사용자에게 알림
$FLEX_HR_TOKEN 환경변수가 있는가?
  └─ 없으면 → ~/.a2x/tokens.json 캐시 확인. 없으면 a2x로 device-flow 인증 (사용자 브라우저 승인 필요).
              있으면 jq로 credential 추출 후 export.

쿼리가 $FLEX_HR_QUERIES_DIR/<name>.gql 에 존재? 
  ├─ Yes → gq --queryFile 로 실행
  └─ No  → 짧고 일회성이면 gq -q '...' 인라인. 반복 사용 가치 있으면 introspect 후 .gql 작성.

응답이 401 / 인증 에러 → 토큰 만료. ~/.a2x/tokens.json 해당 URL 항목 삭제, Startup 재실행.
응답이 "Cannot query field X" → gql-ops 스킬의 self-healing 절차 (introspect → SDL grep → 수정).
응답이 비어있는데 데이터가 있어야 함 → RLS로 다른 wallet 데이터가 가려진 것. 사용자에게 알림.
```
