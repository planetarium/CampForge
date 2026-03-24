# Operating Rules

## Startup

1. gql-ops skill이 로드되어 있는지 확인
2. 환경 변수 확인: `BO_GQL`, `BO_API_KEY`, `BO_SKILL_DIR` — 미설정 시 사용자에게 요청
3. 스키마 사전 조회 하지 않음 (토큰 절약)

## Planet Resolution

사용자가 행성 이름을 말하면 자동 매핑:

| Name | PlanetId | Internal URL |
|------|----------|-------------|
| Odin | `0x100000000000` | `http://odin-internal-rpc.nine-chronicles.com/graphql` |
| Heimdall | `0x100000000001` | `http://heimdall-internal-rpc-1.nine-chronicles.com/graphql` |
| Thor | `0x100000000003` | `http://thor-internal-rpc-1.nine-chronicles.com/graphql` |

## Workflow Rules

- **파이프라인 순서 엄수**: validate → sign → stage → poll → upload-r2 → purge-cache
- **validate 필수**: CSV 검증 실패 시 즉시 중단, 에러 보고
- **sign 결과 보존**: `txId`와 `payload`를 다음 단계에서 사용
- **polling 규칙**: 5초 간격, 2분 타임아웃. `txStatus`가 `SUCCESS` 또는 `FAILURE`일 때 종료
- **멀티 플래닛**: 동일 CSV로 순차 실행 (Odin → Heimdall → Thor)
- **테이블명 추론**: 파일명에서 추론 가능하면 자동 (예: `WorldSheet.csv` → `WorldSheet`)

## Input Handling

| 있는 정보 | 없는 정보 | 행동 |
|-----------|-----------|------|
| Planet + table name | CSV | "패치할 CSV 파일 경로나 내용을 알려주세요" |
| CSV + planet | Table name | 파일명에서 추론, 불가능하면 질문 |
| Table name + CSV | Planet | "어떤 플래닛에 패치할까요? (odin / heimdall / thor)" |

## Error Handling

1. GraphQL 에러 → gql-ops의 self-healing 절차
2. CSV 검증 에러 → `errors` 필드 내용을 사용자에게 표시
3. TX `FAILURE` → `exceptionNames` 확인 후 보고
4. Polling 타임아웃 → 사용자에게 txId 알려주고 수동 확인 안내

## Output Format

- 패치 진행 시 각 단계별 상태 표시 (1/6, 2/6, ...)
- 완료 시 요약 테이블: 행성, 테이블, txId, 상태
- 멀티 플래닛 시 행성별 결과를 개별 행으로 표시
