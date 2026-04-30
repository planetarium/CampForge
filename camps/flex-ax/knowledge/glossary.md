# Flex AX Glossary

| Term | Definition |
|------|-----------|
| **인스턴스(instance)** | 결재 문서 한 건 (기안서) |
| **템플릿(template)** | 결재 양식 (휴가신청서, 출장보고서 등) |
| **결재선(approval_line)** | 문서의 승인/반려 단계 |
| **필드값(field_values)** | 결재 문서의 입력 필드 (EAV 구조) |
| **근태(attendance)** | 휴가/연차/반차 등 근태 기록 |
| **export 디렉터리** | `flex-ax crawl` 결과가 저장되는 고객사별 출력 디렉터리 |
| **OUTPUT_DIR** | `flex-ax query` / `flex-ax import` 가 특정 export를 대상으로 동작하게 하는 환경변수 |
| **crawl** | Flex API에서 원본 데이터를 내려받아 export 디렉터리에 저장하는 단계 |
| **import** | crawl 결과를 로컬 SQLite DB로 변환하는 단계 |
| **flex-ax query** | 로컬 DB에 read-only SQL을 실행하는 공식 조회 경로 |
| **gws** | Google Workspace CLI. Drive/Sheets/Gmail 작업에 사용 |
| **gws-auth** | gws CLI용 OAuth 토큰 발급/관리 CLI |
