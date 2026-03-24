---
name: 9c-backoffice-smoke-test
description: Nine Chronicles Backoffice 부트캠프 설치 후 셀프 테스트
---

# 9C Backoffice Smoke Test

## Prerequisites

- 9c-backoffice skill과 gql-ops skill이 로드되어 있어야 함
- 환경 변수 설정: `BO_GQL`, `BO_API_KEY`, `BO_SKILL_DIR`

## Test Plan

### Group 1: Read-Only Operations

1. 시트 목록 조회 (`sheet-list.gql`)
2. 시트 비교 (`sheet-compare.gql` — Odin, tableNames: ["WorldSheet"])

### Group 2: Validation (Non-Destructive)

1. CSV 검증 (`table-patch-validate.gql` — 유효한 CSV)
2. CSV 검증 (`table-patch-validate.gql` — 의도적 에러 CSV)

### Group 3: Query File Integrity

1. 모든 .gql 파일이 존재하는지 확인 (9개)
2. 각 파일의 mutation/query 이름이 올바른지 확인

## Report Format

| Test | Result | Notes |
|------|--------|-------|
| Sheet List | PASS/FAIL | |
| Sheet Compare | PASS/FAIL | |
| Valid CSV | PASS/FAIL | |
| Invalid CSV | PASS/FAIL | |
| Query Files | PASS/FAIL | X/9 files found |
