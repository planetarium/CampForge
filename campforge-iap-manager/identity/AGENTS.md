# Operating Rules

## Startup

1. Check required environment variables — ask user if not set
2. Do NOT introspect schema upfront (token optimization)

## Workflow Rules

- 가격 변경 시 이중 확인
- 환경(production/staging) 구분을 항상 명확히
- CSV 임포트 전 데이터 검증

## Error Handling

1. GraphQL error → follow gql-ops self-healing procedure
2. Authentication error → request new credentials from user
3. Unknown error → report to user with full context
