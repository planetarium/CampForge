# Operating Rules

## Startup

1. Check required environment variables — ask user if not set
2. 환경변수 로드: `source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null`
3. `flex-ax status` 로 현재 email/password 등록 상태 확인
   - 비대화형 환경에서 인증 정보가 없으면 `FLEX_EMAIL`, `FLEX_PASSWORD` 필요
   - 대화형 환경이면 `flex-ax login` 으로 등록 가능
4. `gws-auth status 2>/dev/null` 로 Google Workspace 인증 상태 확인
   - 인증 OK → `gws gmail users getProfile --params '{"userId":"me"}'` 등으로 실제 접근 가능 여부 확인
   - 인증 없음 → `gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file` 실행 (사용자가 브라우저에서 동의 완료해야 함)
5. `OUTPUT_DIR` 가 특정 export 디렉터리를 가리키는지 확인
   - 여러 법인 export가 있으면 `flex-ax query` 전에 `OUTPUT_DIR=.../output/<customerIdHash>` 로 좁혀야 함

## Workflow Rules

- **데이터 조회는 반드시 `flex-ax query 'SQL'` 명령만 사용한다.**
- **sqlite3, python sqlite3 모듈 등으로 DB 파일에 직접 접근하지 않는다.** output/ 디렉토리의 파일을 직접 읽거나 열지 않는다.
- flex-ax CLI의 query 명령은 read-only이므로 DB 수정 불가
- 크롤링(crawl/import)은 사용자 확인 후 실행
- crawl 인증 실패 시 먼저 `flex-ax login` 상태와 `FLEX_EMAIL` / `FLEX_PASSWORD` 설정을 점검한다
- 개인 급여/평가 등 민감 정보는 명시적 요청 시에만 조회
- Google Workspace 작업(Sheets/Drive/Gmail)은 Startup에서 인증 + 접근 확인 완료 후 사용
- 데이터를 Drive/Sheets에 내보낼 때는 CSV 형식으로 저장 후 업로드. 파일명을 반드시 지정 (예: `expense-report-2026-04.csv`)
- 메일 발송은 반드시 사용자 확인 후 실행

## Error Handling

1. DB not found → `flex-ax crawl` + `flex-ax import` 안내
2. Authentication error (crawl) → `flex-ax login` 재실행 또는 `FLEX_EMAIL` / `FLEX_PASSWORD` 환경변수 확인 안내
3. `export 디렉터리를 명시적으로 지정해 주세요` 오류 → `OUTPUT_DIR` 를 특정 export 디렉터리로 지정하게 안내
4. SQL error → 스키마 확인 후 쿼리 수정
5. GWS auth error → `gws-auth login --scope drive --scope gmail.modify --scope spreadsheets` 안내
6. Unknown error → report to user with full context
