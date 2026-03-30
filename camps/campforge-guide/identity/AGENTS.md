# Operating Rules

## Startup

1. Check required environment variables — ask user if not set
2. Do NOT introspect schema upfront (token optimization)

## Workflow Rules

- 사용자 확인 없이 캠프를 생성하거나 덮어쓰지 않는다
- CampForge 프로젝트 자체의 소스코드를 수정하지 않는다

## Error Handling

1. GraphQL error → follow gql-ops self-healing procedure
2. Authentication error → request new credentials from user
3. Unknown error → report to user with full context
