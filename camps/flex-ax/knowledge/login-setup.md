# flex-ax Login Setup

`flex-cli@0.7.0`부터 로컬 dump 워크플로우의 기본 인증 경로는 Playwriter가 아니라 `login` 기반이다.

## Recommended flow

```bash
flex-ax login
flex-ax status
flex-ax crawl
flex-ax import
```

`login` 성공 시:
- 이메일은 `~/.flex-ax/config.json` 에 저장된다
- 비밀번호는 OS 키링에 저장된다

## Non-interactive flow

에이전트/CI 환경에서는 환경변수로 주입할 수 있다:

```bash
export FLEX_EMAIL="you@example.com"
export FLEX_PASSWORD="..."
flex-ax crawl
flex-ax import
```

또는 `--password-stdin`:

```bash
printf '%s' "$FLEX_PASSWORD" | flex-ax login --password-stdin
```

## Querying with multiple exports

여러 법인 export가 있으면 `query` 전에 `OUTPUT_DIR` 를 특정 export 디렉터리로 좁혀야 한다.

```bash
export OUTPUT_DIR="$HOME/.flex-ax-data/output/<customerIdHash>"
flex-ax query "SELECT * FROM users LIMIT 5"
```

지정하지 않으면 `export 디렉터리를 명시적으로 지정해 주세요` 오류가 날 수 있다.
