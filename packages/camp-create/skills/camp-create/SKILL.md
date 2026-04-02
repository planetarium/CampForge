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

### Step 6: README.md 생성

캠프 루트에 `README.md`를 작성한다. 기존 캠프의 README를 참고하여 다음 내용을 포함한다:

- 캠프 이름과 한 줄 설명
- 스킬 목록
- 플랫폼별 설치 방법 (Claude Code, Codex, OpenClaw)
- Prerequisites (필요한 도구)
- 검증 명령어

### Step 7: 검증

`camp-validate` 스킬을 사용하여 생성 결과를 검증한다.

### Step 8: install.sh 생성

`curl | bash`로 설치할 수 있도록 `install.sh`를 생성한다. v8-admin의 `install.sh`를 참고하여 해당 캠프의 의존성에 맞게 작성한다.

```bash
#!/usr/bin/env bash
# Installer for <camp-name> camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/<camp-name>/install.sh | bash
set -euo pipefail

VERSION="${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="${WORKSPACE:-.}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \
  "dependencies.@campforge/<skill>=$BASE/campforge-<skill>-<version>.tgz"

npx skillpm install

echo "<camp-name> camp installed"
```

외부 CLI 의존성이 있으면 `scripts/install-common.sh`의 공통 함수를 사용한다.

### Step 9: 설치 안내

검증 통과 후, 생성된 캠프를 설치하는 방법을 안내한다:

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/<camp-name>/install.sh | bash
```

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
