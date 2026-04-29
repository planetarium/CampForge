# Operating Rules

**Before proceeding, load the `gql-ops` skill dependency.**

## Startup

1. Check required environment variables — ask user if not set.
2. 환경변수 로드: `source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null`
3. Flex HR agent base URL을 정한다:
   ```bash
   export FLEX_HR_AGENT_URL="${FLEX_HR_AGENT_URL:-https://flex-hr-10780.fly.dev}"
   export FLEX_HR_GQL="${FLEX_HR_AGENT_URL}/graphql"
   export FLEX_HR_QUERIES_DIR="$(pwd)/knowledge/queries"
   ```
4. a2x로 1회 인증한 뒤 토큰을 환경변수로 export한다:
   ```bash
   if ! jq -e --arg u "$FLEX_HR_AGENT_URL" '.[$u]' ~/.a2x/tokens.json >/dev/null 2>&1; then
     a2x a2a send "$FLEX_HR_AGENT_URL" "ping" >/dev/null
   fi
   if ! FLEX_HR_TOKEN="$(jq -er --arg u "$FLEX_HR_AGENT_URL" '.[$u][0].credential' ~/.a2x/tokens.json)"; then
     echo "Failed to extract a cached credential for $FLEX_HR_AGENT_URL from ~/.a2x/tokens.json." >&2
     exit 1
   fi
   export FLEX_HR_TOKEN
   ```
5. `gws-auth status 2>/dev/null` 로 Google Workspace 인증 상태 확인
6. Do NOT introspect schema upfront.

## Workflow Rules

- **데이터 조회는 `gq $FLEX_HR_GQL -H "Authorization: Bearer $FLEX_HR_TOKEN" ...` 호출만 사용한다.**
- **로컬 sqlite, sqlite3 명령, python sqlite3 모듈 등 로컬 DB 파일에 직접 접근하지 않는다.**
- 자주 쓰는 쿼리는 `$FLEX_HR_QUERIES_DIR/<name>.gql` 파일로 저장해 재사용한다.
- 모든 호출에 `-l` 플래그를 붙여 토큰을 절약한다.
- 개인 급여/평가 등 민감 정보는 명시적 요청 시에만 조회한다.
- 데이터 변경/생성/삭제 mutation은 사용자에게 의도를 재확인한 뒤 실행한다.
- Google Workspace 작업은 인증 확인 완료 후 사용한다.

## Error Handling

1. `a2x: command not found` → `install.sh`가 정상 종료됐는지, `~/.local/bin` 가 PATH에 있는지 확인
2. GraphQL이 인증 에러로 실패 → `~/.a2x/tokens.json` 의 해당 URL 항목을 삭제하고 Startup 4단계를 다시 수행
3. `Cannot query field "X"` → `gql-ops` 스킬의 self-healing 절차를 따른다
4. GraphQL 응답이 비어있는데 사용자가 데이터가 있어야 한다고 하면 → RLS 가능성을 사용자에게 알린다
5. GWS auth error → `gws-auth login --scope drive --scope gmail.modify --scope spreadsheets` 안내
