# Flex AX Glossary

| Term | Definition |
|------|-----------|
| **인스턴스(instance)** | 결재 문서 한 건 (기안서) |
| **템플릿(template)** | 결재 양식 (휴가신청서, 출장보고서 등) |
| **결재선(approval_line)** | 문서의 승인/반려 단계 |
| **필드값(field_values)** | 결재 문서의 입력 필드 (EAV 구조) |
| **근태(attendance)** | 휴가/연차/반차 등 근태 기록 |
| **A2A** | Agent2Agent 프로토콜. 외부 에이전트와 JSON-RPC로 통신 |
| **a2x** | A2A 프로토콜 클라이언트 CLI. 본 캠프에서는 인증 토큰 발급 용도로만 사용 |
| **SIWE** | Sign-In with Ethereum (EIP-4361). a2x device flow가 발급하는 토큰의 형식 |
| **PostGraphile** | PostgreSQL 스키마에서 GraphQL API를 자동 생성하는 미들웨어 |
| **RLS** | Row-Level Security. SIWE 토큰에 묶인 wallet의 데이터만 보이도록 PostgreSQL이 행 단위로 격리 |
| **gq** | graphqurl. CLI에서 GraphQL 쿼리를 보내기 위한 도구 (`@campforge/gql-ops` 스킬에서 안내) |
| **Flex HR 엔드포인트** | `$FLEX_HR_AGENT_URL` (기본 `https://flex-hr-10780.fly.dev`) — base URL. GraphQL은 `$FLEX_HR_GQL` (`<base>/graphql`) |
