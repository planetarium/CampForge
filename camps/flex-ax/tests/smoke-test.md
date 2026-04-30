# Smoke Tests

## 01 — 사용자별 결재 현황 조회
- **Prompt**: 홍길동의 최근 결재 문서 보여줘
- **Expect**: users + instances JOIN하여 결과 조회

## 02 — 근태 조회
- **Prompt**: 이번 달 휴가 사용 현황
- **Expect**: attendance 테이블에서 날짜 필터링하여 조회

## 03 — 크롤링 실행
- **Prompt**: 데이터 최신화해줘
- **Expect**: 필요 시 `flex-ax status` / `flex-ax login` 확인 후 crawl → import 실행

## 04 — 익스펜스 데이터 Drive 업로드
- **Prompt**: 이번 달 익스펜스 데이터 정리해서 Drive에 올려줘
- **Expect**: 필요 시 `OUTPUT_DIR` 를 특정 export로 지정 후 flex-ax query로 데이터 추출 → CSV/Sheets 생성 → Drive 업로드 → 링크 반환

## 05 — 익스펜스 메일 대조
- **Prompt**: 메일로 들어온 익스펜스 내역이랑 결재 데이터 맞는지 확인해줘
- **Expect**: Gmail에서 익스펜스 메일 조회 → flex-ax query로 결재 데이터 대조 → 불일치 리포트
