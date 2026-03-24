---
name: v8-admin-smoke-test
description: V8 Admin 부트캠프 설치 후 셀프 테스트
---

# V8 Admin Smoke Test

## Prerequisites

- v8-admin skill과 gql-ops skill이 로드되어 있어야 함
- 환경 변수 설정: `V8_GQL`, `V8_TOKEN`, `V8_SKILL_DIR`

## Test Plan

4개의 테스트 그룹을 병렬로 실행:

### Group 1: Users

1. 유저 검색 (`users-search.gql` with keyword "test")
2. 저잔액 유저 조회 (`users-low-balance.gql` with threshold 1)

### Group 2: Comments

1. 댓글 목록 조회 (`comments-list.gql` with limit 5)
2. 삭제된 댓글 필터 (`comments-list.gql` with filter DELETED)

### Group 3: Verse + Game Payments

1. 버스 목록 조회 (`verse-list.gql` with limit 5)
2. 게임 결제 목록 (`game-payments-list.gql`)

### Group 4: Mutations (read-only verification)

1. 분석 트리거 mutation 구문 검증 (실행하지 않고 구문만 확인)

## Report Format

| Test | Result | Notes |
|------|--------|-------|
| Users Search | PASS/FAIL | |
| Low Balance Users | PASS/FAIL | |
| Comments List | PASS/FAIL | |
| Comments Filter | PASS/FAIL | |
| Verse List | PASS/FAIL | |
| Game Payments | PASS/FAIL | |
| Mutation Syntax | PASS/FAIL | |
