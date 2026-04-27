# Operating Rules

**Before proceeding, load the `gql-ops` skill dependency.** It provides
schema introspection, query file conventions, and self-healing guidance
used by this camp.

## Startup

1. Check required environment variables — ask user if not set.
2. 환경변수 로드: `source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null`
3. Flex HR agent base URL을 정한다 (없으면 기본값 사용 후 사용자에게 알림):
   ```bash
   export FLEX_HR_AGENT_URL="${FLEX_HR_AGENT_URL:-https://flex-hr-10780.fly.dev}"
   export FLEX_HR_GQL="${FLEX_HR_AGENT_URL}/graphql"
   export FLEX_HR_QUERIES_DIR="<absolute path to camp's knowledge/queries>"
   ```
4. a2x로 1회 인증한 뒤 토큰을 환경변수로 export한다:
   ```bash
   # If no token is cached for this URL, send a ping to trigger device-flow auth.
   # The CLI prints a one-time URL with user_code; relay it to the user and wait
   # for browser approval — the agent cannot open the browser.
   if ! jq -e --arg u "$FLEX_HR_AGENT_URL" '.[$u]' ~/.a2x/tokens.json >/dev/null 2>&1; then
     a2x a2a send "$FLEX_HR_AGENT_URL" "ping" >/dev/null
   fi
   export FLEX_HR_TOKEN="$(jq -r --arg u "$FLEX_HR_AGENT_URL" '.[$u][0].credential' ~/.a2x/tokens.json)"
   ```
5. `gws-auth status 2>/dev/null` 로 Google Workspace 인증 상태 확인
   - 인증 OK → `gws gmail users getProfile --params '{"userId":"me"}'` 등으로 실제 접근 가능 여부 확인
   - 인증 없음 → `gws-auth login --scope gmail.modify --scope spreadsheets --scope drive.file` 실행 (사용자가 브라우저에서 동의 완료해야 함)
6. Do NOT introspect schema upfront (token optimization).

## Workflow Rules

- **데이터 조회는 `gq $FLEX_HR_GQL -H "Authorization: Bearer $FLEX_HR_TOKEN" ...` 호출만 사용한다.**
  ```bash
  gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" \
    --queryFile "$FLEX_HR_QUERIES_DIR/<name>.gql" -j '<variables>' -l
  ```
- **로컬 sqlite, sqlite3 명령, python sqlite3 모듈 등 로컬 DB 파일에 직접 접근하지 않는다.** 데이터는 항상 GraphQL 호출을 통해서만 가져온다.
- 자주 쓰는 쿼리는 `$FLEX_HR_QUERIES_DIR/<name>.gql` 파일로 저장해 재사용한다 (디렉토리는 비어있을 수 있음 — 새 쿼리는 introspection 후 작성).
- 짧은 mutation은 인라인 `-q`로 보내도 된다.
- 모든 호출에 `-l` (compact) 플래그를 붙여 토큰을 절약한다.
- 개인 급여/평가 등 민감 정보는 명시적 요청 시에만 조회한다.
- 데이터 변경/생성/삭제 mutation은 사용자에게 의도를 재확인한 뒤 실행한다.
- Google Workspace 작업(Sheets/Drive/Gmail)은 Startup에서 인증 + 접근 확인 완료 후 사용
- 데이터를 Drive/Sheets에 내보낼 때는 CSV 형식으로 저장 후 업로드. 파일명을 반드시 지정 (예: `expense-report-2026-04.csv`)
- 메일 발송은 반드시 사용자 확인 후 실행

## PostGraphile conventions

This service exposes a PostGraphile-generated GraphQL schema:

- **Connection types**: List queries return `{ nodes: [...], totalCount }` (e.g. `allEmployees { nodes { id } totalCount }`).
- **Filtering**: Use `condition` for exact matches (e.g. `allAttendances(condition: { employeeId: 1 })`).
- **Sorting**: `orderBy` takes UPPER_SNAKE enum values (e.g. `CREATED_AT_DESC`).
- **Pagination**: `first`, `last`, `offset`, `before`, `after`.
- **Field naming**: SQL `snake_case` → GraphQL `camelCase` (e.g. `created_at` → `createdAt`).
- **Mutations**: PostGraphile auto-generates `createX`, `updateXById`, `deleteXById`. Each takes an `input` object — create inputs nest the entity, update inputs include `id` + `patch`.
- **RLS**: Row-Level Security restricts visible rows to those owned by the wallet bound to the SIWE token.

## Error Handling

1. `a2x: command not found` → `install.sh`가 정상 종료됐는지, `~/.local/bin` 가 PATH에 있는지 확인. 자세한 설치는 `@campforge/a2x` 스킬의 SKILL.md 참조.
2. GraphQL이 인증 에러로 실패 (`401`, `Authentication required`) → 토큰이 만료된 것. `~/.a2x/tokens.json` 의 해당 URL 항목을 삭제하고 Startup 4단계를 다시 수행한다.
3. `Cannot query field "X"`, `Unknown type "X"` → `gql-ops` 스킬의 self-healing 절차를 따른다 (`gq --introspect`로 SDL을 받아 필드명/타입명을 수정한 뒤 재시도).
4. GraphQL 응답이 비어있는데 사용자가 데이터가 있어야 한다고 하면 → RLS로 인해 다른 wallet의 데이터는 보이지 않는다는 점을 사용자에게 알린다.
5. GWS auth error → `gws-auth login --scope drive --scope gmail.modify --scope spreadsheets` 안내
6. Unknown error → report to user with full context
