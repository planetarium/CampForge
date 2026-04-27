# Smoke Tests

> 모든 시나리오는 `gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" ...`
> 호출로 처리한다. `a2x`는 최초 device-flow 인증으로 `$FLEX_HR_TOKEN`을 발급/갱신
> 하는 용도로만 사용한다. 로컬 DB 접근(`sqlite3`, `flex-ax query` 등)은 사용하지
> 않는다.

## 01 — 사용자별 결재 현황 조회
- **Prompt**: 홍길동의 최근 결재 문서 보여줘
- **Expect**: `allEmployees(condition: { ... })` 로 사용자 매칭 → 그 employeeId로 `allApprovals` 조회 → 최근순 정렬

## 02 — 근태 조회
- **Prompt**: 이번 달 휴가 사용 현황
- **Expect**: `allAttendances(condition: { ... }, orderBy: CREATED_AT_DESC)` 로 이번 달 범위 조회 → 휴가 유형별 집계

## 03 — 익스펜스 데이터 Drive 업로드
- **Prompt**: 이번 달 익스펜스 데이터 정리해서 Drive에 올려줘
- **Expect**: 익스펜스 결재 GraphQL 쿼리 → CSV 생성 → `gws drive` 업로드 → 링크 반환

## 04 — 익스펜스 메일 대조
- **Prompt**: 메일로 들어온 익스펜스 내역이랑 결재 데이터 맞는지 확인해줘
- **Expect**: `gws gmail`로 익스펜스 메일 조회 → 같은 기간 결재 GraphQL 쿼리 → 불일치 항목 리포트
