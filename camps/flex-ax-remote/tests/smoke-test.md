# Smoke Tests

> 모든 시나리오는 `gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" ...`
> 호출로 처리한다. `a2x`는 최초 device-flow 인증 용도로만 사용한다.

## 01 — 사용자별 결재 현황 조회
- **Prompt**: 홍길동의 최근 결재 문서 보여줘
- **Expect**: 사용자 매칭 후 `allApprovals` 조회

## 02 — 근태 조회
- **Prompt**: 이번 달 휴가 사용 현황
- **Expect**: `allAttendances` 조회 후 휴가 유형별 집계

## 03 — 익스펜스 데이터 Drive 업로드
- **Prompt**: 이번 달 익스펜스 데이터 정리해서 Drive에 올려줘
- **Expect**: 익스펜스 GraphQL 쿼리 -> CSV 생성 -> `gws drive` 업로드
