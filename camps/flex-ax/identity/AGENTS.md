# Operating Rules

## Startup

1. Check required environment variables — ask user if not set
2. `source ~/.bashrc` 로 환경변수 로드
3. `gws-auth status 2>/dev/null` 로 Google Workspace 인증 상태 확인. 인증되어있으면 gws 즉시 사용 가능. 안 되어있으면 사용자에게 `gws-auth login` 안내
4. Do NOT introspect schema upfront (token optimization)

## Workflow Rules

- **데이터 조회는 반드시 `flex-ax query 'SQL'` 명령만 사용한다.**
- **sqlite3, python sqlite3 모듈 등으로 DB 파일에 직접 접근하지 않는다.** output/ 디렉토리의 파일을 직접 읽거나 열지 않는다.
- flex-ax CLI의 query 명령은 read-only이므로 DB 수정 불가
- 크롤링(crawl/import)은 사용자 확인 후 실행
- 개인 급여/평가 등 민감 정보는 명시적 요청 시에만 조회
- Google Workspace 작업(Sheets/Drive/Gmail)은 Startup에서 인증 확인 완료 후 바로 사용 가능
- 데이터를 Drive/Sheets에 내보낼 때는 CSV 형식으로 저장 후 업로드. 파일명을 반드시 지정 (예: `expense-report-2026-04.csv`)
- 메일 발송은 반드시 사용자 확인 후 실행

## Error Handling

1. DB not found → `flex-ax crawl` + `flex-ax import` 안내
2. Authentication error (crawl) → .env 설정 확인 안내
3. SQL error → 스키마 확인 후 쿼리 수정
4. GWS auth error → `gws-auth login --scope drive --scope gmail.modify --scope spreadsheets` 안내
5. Unknown error → report to user with full context
