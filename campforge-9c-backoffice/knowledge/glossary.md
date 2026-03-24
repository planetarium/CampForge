# Nine Chronicles Backoffice Glossary

## Planets

| Planet | PlanetId | Description |
|--------|----------|-------------|
| **Odin** | `0x100000000000` | 메인 프로덕션 행성 |
| **Heimdall** | `0x100000000001` | 세컨드 행성 |
| **Thor** | `0x100000000003` | 서드 행성 |

## Table Patch Pipeline

| Stage | Description | Input | Output |
|-------|-------------|-------|--------|
| **Validate** | CSV 포맷 검증 | tableName, csvContent | isValid, errors, warnings |
| **Sign** | 블록체인 트랜잭션 서명 | planetId, url, tableName, tableCsv | txId, payload |
| **Stage** | 서명된 트랜잭션 제출 | planetId, url, payload, tableName, tableCsv | success |
| **Poll TX Result** | 트랜잭션 상태 폴링 | planetId, url, txId | txStatus, blockIndex |
| **Upload R2** | Cloudflare R2에 업로드 | planetId, url, tableName, tableCsv | success |
| **Purge Cache** | CDN 캐시 무효화 | planetId, url, tableName | success |

## Transaction Status

| Status | Meaning |
|--------|---------|
| `SUCCESS` | 블록체인에 성공적으로 반영됨 |
| `FAILURE` | 실패. `exceptionNames` 필드에서 원인 확인 |
| (기타) | 아직 처리 중. 5초 후 재조회 |

## Key Concepts

| Term | Definition |
|------|-----------|
| **Sheet** | Nine Chronicles의 게임 데이터 테이블 (예: WorldSheet, StageSheet) |
| **Table Patch** | 시트의 CSV 데이터를 블록체인에 반영하는 과정 |
| **R2** | Cloudflare R2 오브젝트 스토리지. 패치된 테이블 데이터의 캐시 저장소 |
| **CDN Purge** | R2 앞단 CDN 캐시를 무효화하여 최신 데이터가 서빙되도록 함 |
| **OAG** | Open API Gateway. Planetarium의 GraphQL 집약 게이트웨이 |
| **Payload** | 서명된 블록체인 트랜잭션의 hex 직렬화 데이터 |

## Response Format

모든 응답 공통 구조:
```json
{ "success": bool, "message": string?, "data": any? }
```

예외: `check-deleted-addresses` → `results` 대신 `data` 사용
