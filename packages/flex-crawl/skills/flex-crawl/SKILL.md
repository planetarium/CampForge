---
name: flex-crawl
description: >
  flex API를 크롤링하여 로컬 데이터를 최신 상태로 갱신한다.
  Triggers: "데이터 최신화", "크롤링", "DB 갱신", "데이터 새로 가져와"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# flex-crawl

## When to Use

- DB가 없거나 오래되어 최신 데이터가 필요할 때
- 사용자가 명시적으로 크롤링/갱신을 요청할 때
- query 결과가 비어있어 데이터 수집이 필요할 때

## Environment

```bash
# flex-ax 프로젝트 디렉토리
FLEX_AX_DIR="<flex-ax-project>/apps/flex-cli"

# 인증 설정 (.env 파일에 정의)
# AUTH_MODE: credentials | sso | playwriter
# FLEX_EMAIL, FLEX_PASSWORD (credentials 모드)
```

## Workflow

1. **사용자 확인** — 크롤링은 시간이 걸리므로 실행 전 반드시 확인
2. **크롤링 실행** — `flex-ax crawl` (또는 `--auth <mode>` 옵션 사용)
3. **DB 변환** — `flex-ax import`
4. **결과 리포트** — 템플릿/인스턴스/근태 각 건수와 에러 요약

### 명령어

```bash
# 기본 크롤링 (credentials 모드)
flex-ax crawl

# SSO 인증 모드
flex-ax --auth sso crawl

# 크롤링 결과 → DB 변환
flex-ax import
```

## Output Format

```
크롤링 완료:
- 템플릿: N건
- 결재 문서: N건
- 근태: N건
- 소요 시간: Ns
- 에러: N건 (있으면 상세 표시)
```

## Stop Conditions

- crawl + import 모두 성공
- 인증 실패 → .env 설정 확인 안내
- 크롤링 에러(exit code 2) → 에러 목록 표시 후 재시도 여부 확인
