---
name: camp-add-skill
description: >
  기존 캠프에 새 스킬을 추가한다. campforge add-skill CLI를 사용하여
  scaffold를 생성하거나 npm 패키지 참조를 추가한다.
  Triggers: "스킬 추가해줘", "add a skill to this camp"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# Camp Add Skill

## When to Use

이미 존재하는 캠프에 새로운 스킬을 추가하고 싶을 때.

## Environment

```bash
CAMPFORGE_CLI="<campforge-project>/cli"
```

## Workflow

### Step 1: 스킬 정보 수집

- **Skill ID** (kebab-case, 예: `cost-analyzer`)
- **설명** (한 문장)
- **소스 타입**: scaffold (새로 만들기) 또는 reference (npm 패키지 참조)

### Step 2: add-skill 실행

**새 스킬 scaffold 생성:**

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts add-skill \
  --camp <camp-directory> \
  --skill <skill-id> \
  --description "스킬 설명"
```

**npm 패키지 참조 추가:**

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts add-skill \
  --camp <camp-directory> \
  --skill <skill-id> \
  --source reference \
  --ref @campforge/some-package
```

**CLI 옵션:**
- `--camp <dir>` — 대상 캠프 디렉토리 (필수)
- `--skill <id>` — 스킬 ID (필수)
- `--source <type>` — scaffold | reference (기본: scaffold)
- `--ref <ref>` — npm 패키지명 (reference 소스일 때 필수)
- `--description <desc>` — 스킬 설명

### Step 3: SKILL.md 채우기

scaffold로 생성한 경우 `skills/{skill-id}/SKILL.md`에 TODO가 남아있다. 실제 내용으로 채운다.

### Step 4: 확인

- `manifest.yaml`의 `skills.optional`에 자동 추가됨
- `skills/{skill-id}/SKILL.md` 파일 생성 확인
- 필요하면 `camp-validate`로 전체 검증

## Output Format

```
Adding skill "cost-analyzer" to /path/to/camp
Scaffold created at skills/cost-analyzer/SKILL.md
Added "cost-analyzer" to manifest.yaml (optional)
```

## Stop Conditions

- 스킬 추가 및 SKILL.md 채우기 완료
- manifest.yaml 없음 — 올바른 캠프 디렉토리인지 확인 요청
- 오류 발생 — 에러 메시지와 수동 추가 방법 안내
