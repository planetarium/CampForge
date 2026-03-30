---
name: camp-bench
description: >
  캠프 성능 벤치마크. smoke test 시나리오를 서브에이전트로 실행하고
  tool calls, 토큰, 시간을 측정한다. 액션별 상세 로그도 수집한다.
  Triggers: "캠프 벤치마크", "camp bench", "성능 측정해줘"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# Camp Bench

## When to Use

캠프의 성능을 측정하고 개선점을 찾고 싶을 때. smoke test 시나리오를 실행하여 정량적 지표를 수집한다.

## 측정 지표

| 지표 | 설명 |
|------|------|
| **Tool Calls** | 서브에이전트가 사용한 총 tool 호출 횟수 |
| **Tokens** | 총 토큰 소모량 |
| **Duration** | 총 실행 시간 (ms) |
| **Action Log** | 각 tool call의 종류, 대상, 소요 내역 |

## Workflow

### Step 1: 대상 캠프 확인

벤치마크할 캠프 경로와 smoke test 파일을 확인한다:
- `<camp>/tests/smoke-test.md`
- `<camp>/skills/*/SKILL.md`

### Step 2: 환경 변수 확인

캠프의 SKILL.md에 명시된 환경 변수가 설정되어 있는지 확인한다. 없으면 사용자에게 요청한다.

### Step 3: 서브에이전트 프롬프트 구성

서브에이전트에게 보낼 프롬프트를 구성한다. **핵심: 파일 읽기를 최소화하기 위해 필요한 정보를 프롬프트에 인라인한다.**

프롬프트에 반드시 포함할 것:
1. SKILL.md 내용 (미리 읽어서 인라인)
2. smoke-test.md의 테스트 시나리오
3. 환경 변수 값
4. 아래의 액션 로깅 지시

### Step 4: 서브에이전트에 액션 로깅 지시

서브에이전트 프롬프트 끝에 반드시 다음을 포함한다:

```
## Action Logging (MANDATORY)

모든 tool call을 아래 형식으로 기록하고 최종 결과에 포함하라:

### Action Log
| # | Tool | Target | Purpose |
|---|------|--------|---------|
| 1 | Bash | gq ... users-search | Users Search 테스트 |
| 2 | Bash | gq ... comments-list | Comments List 테스트 |
| ... | | | |

- Read, Bash, Grep 등 tool 종류를 명시
- Target은 파일 경로 또는 명령어 요약
- 불필요한 파일 읽기를 하지 말 것 — 프롬프트에 제공된 정보를 사용
- 독립적인 테스트는 가능한 한 하나의 Bash 호출로 합쳐서 실행
```

### Step 5: 서브에이전트 실행 및 결과 수집

Agent tool로 서브에이전트를 실행한다. 반환 결과에서 수집:
- `tool_uses` (자동 반환됨)
- `total_tokens` (자동 반환됨)
- `duration_ms` (자동 반환됨)
- Action Log (프롬프트 지시로 수집)

### Step 6: 벤치마크 리포트 작성

```
## Benchmark Report: {camp-name}

### Summary
| Metric | Value |
|--------|-------|
| Tool Calls | N |
| Tokens | N |
| Duration | N ms |

### Action Log
| # | Tool | Target | Purpose |
|---|------|--------|---------|
| ... | | | |

### Test Results
| Test | Result | Notes |
|------|--------|-------|
| ... | | |

### Optimization Suggestions
- (액션 로그 기반으로 개선점 제안)
```

### Step 7: 개선점 제안

액션 로그를 분석하여 제안한다:
- **불필요한 Read** — 프롬프트에 인라인 가능한 파일을 읽었는가?
- **Bash 합치기** — 독립적인 gq 호출을 하나로 묶을 수 있는가?
- **SKILL.md 개선** — 워크플로우 지시가 불명확하여 에이전트가 추가 탐색을 했는가?

## Output Format

위의 Benchmark Report 형식을 따른다.

## Stop Conditions

- 벤치마크 리포트 출력 완료
- 환경 변수 미설정 — 사용자에게 요청 후 대기
- 서브에이전트 실행 실패 — 에러 보고
