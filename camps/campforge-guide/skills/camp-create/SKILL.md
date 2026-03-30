---
name: camp-create
description: >
  CampForge로 새 캠프를 생성한다. domain-spec.yaml 작성 지원, 인터뷰 모드,
  CLI 실행, scaffold 확인 및 SKILL.md 채우기까지 전 과정을 안내한다.
  Triggers: "새 캠프 만들어줘", "create a camp", "부트캠프 생성"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# Camp Create

## When to Use

사용자가 새로운 에이전트 캠프를 만들고 싶을 때. "새 캠프 만들어줘", "create a camp", "부트캠프 생성" 등의 요청에 반응한다.

## 두 가지 생성 경로

| 경로 | 설명 | 추천 상황 |
|------|------|-----------|
| **인터뷰 모드** | `/interview` 스킬로 대화형 진행 | 도메인이 아직 정리되지 않았을 때 |
| **CLI 직접 실행** | domain-spec.yaml을 먼저 작성 후 CLI | 요구사항이 명확할 때 |

## Environment

```bash
# CampForge CLI 경로 (프로젝트 루트 기준)
CAMPFORGE_CLI="<campforge-project>/cli"
```

## Workflow

### Step 1: 요구사항 파악

사용자에게 최소한 다음을 확인한다:
- **도메인 ID** (kebab-case, 예: `devops-sre`)
- **역할 설명** (한두 문장)
- **핵심 스킬 목록** (각 스킬의 설명과 워크플로우)

사용자가 답을 모르면 합리적인 기본값을 제안한다. 모든 걸 물어보지 말고 빠르게 진행한다.

### Step 2: domain-spec.yaml 작성

수집한 정보로 `domains/{domain-id}.yaml` 파일을 작성한다.

```yaml
domain:
  id: "my-domain"
  name: "My Domain Name"
  identity:
    role_template: "You are a {level} agent that..."
    core_values:
      - "값 1"
    boundaries:
      - "경계 1"
  curriculum:
    core:
      - skill_id: "my-skill"
        source: "generate"
        spec:
          description: "스킬 설명"
          workflow:
            - "Step 1"
            - "Step 2"
          tools_needed: ["tool-name"]
  knowledge:
    glossary:
      "용어": "정의"
  test_scenarios:
    - name: "테스트 이름"
      prompt: "테스트 프롬프트"
      expect: "기대 결과"
```

### Step 3: campforge create 실행

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts create \
  --from ../domains/{domain-id}.yaml \
  --persona senior \
  --language ko
```

**CLI 옵션:**
- `--from <path>` — domain-spec.yaml 경로 (필수)
- `--persona <level>` — junior | mid | senior | lead (기본: senior)
- `--language <lang>` — ko | en (기본: ko)
- `--output <dir>` — 출력 디렉토리 (기본: `campforge-{domain-id}`)
- `--extras <skills>` — 쉼표 구분 elective skill ID
- `--adapters <list>` — 쉼표 구분 어댑터 (기본: claude-code,openclaw,generic)

### Step 4: camps/ 디렉토리로 이동

생성된 캠프를 `camps/` 디렉토리로 옮긴다:

```bash
mv $CAMPFORGE_CLI/campforge-{domain-id} <campforge-project>/camps/
```

### Step 5: SKILL.md 채우기

생성된 각 `skills/*/SKILL.md` 파일에 TODO가 남아있다. 기존 캠프의 SKILL.md를 참고하여 실제 내용으로 채운다:

- When to Use 구체화
- Workflow에 실제 명령어/API 호출 예시 추가
- Environment variables 정의
- Output Format 작성

### Step 6: 검증

`camp-validate` 스킬을 사용하여 생성 결과를 검증한다.

### Step 7: install-remote.sh 생성

원격 에이전트(예: OpenClaw on Docker)에서 curl 한 줄로 스킬을 설치할 수 있도록 `install-remote.sh`를 생성한다.

```bash
#!/usr/bin/env bash
# Remote installer for <camp-name> skill (run on OpenClaw or any agent workspace)
# Usage: curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/<camp-name>/install-remote.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/planetarium/CampForge/main"
WS="${WORKSPACE:-workspace}"

# 의존성 설치 (gql-ops 등)
# 각 스킬의 SKILL.md 및 하위 파일(queries/, references/ 등) 설치
```

v8-admin의 `install-remote.sh`를 참고하여 해당 캠프의 스킬 파일 구조에 맞게 작성한다.

### Step 8: 설치 안내

검증 통과 후, 생성된 캠프를 에이전트에 설치하는 방법을 안내한다:

```bash
# 로컬 설치
cd <camp-directory> && ./campforge-cli.sh

# 원격 설치 (OpenClaw 등)
curl -sL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/<camp-name>/install-remote.sh | bash
```

이 스크립트가 현재 환경을 감지하여 적절한 어댑터(Claude Code, OpenClaw 등)를 자동 실행한다.

## Output Format

각 단계 완료 시 간결하게 상태를 알려준다:
- `domain-spec.yaml 작성 완료`
- `scaffold 생성 완료 — skills/에 TODO 3개`
- `SKILL.md 채우기 완료`
- `검증 통과`
- `설치: cd <camp> && ./campforge-cli.sh`

## Stop Conditions

- 캠프 생성 및 SKILL.md 채우기까지 완료
- 사용자가 중단 요청
- CLI 오류 발생 — 오류 메시지를 보여주고 수정 방법 안내
