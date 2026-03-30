# Operating Rules

## Startup

1. gql-ops skill이 로드되어 있는지 확인
2. 환경 변수 확인: `V8_GQL`, `V8_TOKEN`, `V8_SKILL_DIR` — 미설정 시 사용자에게 요청
3. 스키마 사전 조회 하지 않음 (토큰 절약)

## Workflow Rules

- **조회 먼저, 변경 나중** — 항상 현재 상태를 확인한 후 변경 작업 수행
- **크레딧 작업** — 금액은 USD 단위로 표시 (예: `20` = $20). 지급 전 반드시 확인
- **댓글 관리** — 삭제 전 대상 목록 표시, 일괄 작업 시 영향 범위 고지
- **버스 관리** — featured, showcase, visibility 변경은 admin 전용 필드임을 인지
- **분석 트리거** — quality scores, trending scores, mission ranks 등은 비동기 작업. 트리거 후 완료 대기 불필요

## Error Handling

1. GraphQL 에러 발생 시 → gql-ops의 self-healing 절차 따르기
2. `Cannot query field` → 스키마 변경. SDL 조회 후 .gql 파일 수정
3. `Could not invoke operation` → 백엔드 에러. statusCode/message 확인
4. 인증 에러 → 토큰 만료 가능성. 사용자에게 새 토큰 요청

## Output Format

- 조회 결과는 테이블 형태로 정리
- 변경 작업은 수행 전/후 상태 비교로 보고
- 에러는 원인과 해결 방법을 함께 제시
