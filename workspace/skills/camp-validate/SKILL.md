---
name: camp-validate
description: >
  캠프 디렉토리의 구조와 설정을 검증한다. campforge validate를 실행하고
  결과를 해석하여 수정 방법을 안내한다.
  Triggers: "캠프 검증해줘", "validate this camp", "이거 맞게 만든 거야?"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# Camp Validate

## When to Use

캠프를 생성하거나 수정한 후 구조가 올바른지 확인하고 싶을 때. 캠프 생성(camp-create) 마지막 단계에서도 자동으로 사용된다.

## Environment

```bash
CAMPFORGE_CLI="<campforge-project>/cli"
```

## Workflow

### Step 1: validate 실행

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts validate <camp-directory>
```

### Step 2: 결과 해석

검증 항목 (총 10가지):

| # | 검증 항목 | 흔한 실패 원인 |
|---|-----------|---------------|
| 1 | manifest.yaml 존재 및 파싱 | YAML 문법 오류, 필수 필드 누락 |
| 2 | identity/ 디렉토리 | 디렉토리 자체가 없음 |
| 3 | identity/{SOUL,IDENTITY,AGENTS}.md | 파일 누락 |
| 4 | skills/{id}/SKILL.md 존재 | manifest의 required와 실제 파일 불일치 |
| 5 | SKILL.md frontmatter 유효성 | name, description 필드 누락 |
| 6 | 어댑터 install.sh 존재 | adapters/ 디렉토리가 비어있음 |
| 7 | package.json (의존성 선언 시) | skill 의존성이 있는데 package.json 없음 |
| 8 | campforge-cli.sh 존재 | 파일 누락 |
| 9 | README.md 존재 | 플랫폼별 설치 가이드 누락 |
| 10 | install-remote.sh 존재 | 원격 설치 스크립트 누락 |

### Step 3: 오류 수정 안내

실패한 항목에 대해 구체적인 수정 방법을 안내한다. 직접 수정이 가능한 경우 사용자 확인 후 수정한다.

## Output Format

```
Validating: /path/to/camp

✓ manifest.yaml exists and is valid
✓ identity/ directory exists
✗ skills/my-skill/SKILL.md exists    ← 수정 필요

N passed, M failed
```

실패 항목이 있으면 수정 방법을 바로 이어서 안내한다.

## Stop Conditions

- 모든 검증 통과
- 실패 항목 발견 — 수정 방법 안내 후 사용자가 재검증 요청하면 다시 실행
- CLI 오류 — 에러 메시지 보여주고 중단
