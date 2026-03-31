---
name: camp-sync
description: >
  domain-spec.yaml 변경사항을 기존 캠프에 반영한다. campforge sync를 실행하여
  identity, knowledge, manifest 등 파생 파일만 업데이트하고 SKILL.md는 보존한다.
  Triggers: "도메인 스펙 변경 반영해줘", "캠프 싱크해줘", "sync this camp"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# Camp Sync

## When to Use

domain-spec.yaml을 수정한 뒤 기존 캠프에 반영하고 싶을 때. 예:
- 핵심 가치/경계 추가·수정
- 용어 정의 변경
- 새 스킬을 curriculum에 추가
- 페르소나 레벨 변경

## 덮어쓰기 범위

| 안전하게 덮어쓰기 | 절대 안 건드림 |
|---|---|
| identity/ (SOUL, IDENTITY, AGENTS.md) | skills/*/SKILL.md (기존) |
| knowledge/glossary.md | skills 하위 사용자 파일 (queries/*.gql 등) |
| manifest.yaml, package.json | |
| adapters/*/install.sh | |
| tests/smoke-test.md | |

## Environment

```bash
CAMPFORGE_CLI="<campforge-project>/cli"
```

## Workflow

### Step 1: 변경 사항 미리보기

먼저 dry-run으로 무엇이 바뀌는지 확인한다:

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts sync \
  --camp <camp-directory> \
  --from <domain-spec.yaml> \
  --dry-run
```

사용자에게 결과를 보여주고 진행 여부를 확인받는다.

### Step 2: sync 실행

```bash
cd $CAMPFORGE_CLI && ./node_modules/.bin/tsx bin/campforge.ts sync \
  --camp <camp-directory> \
  --from <domain-spec.yaml>
```

**CLI 옵션:**
- `--camp <dir>` — 대상 캠프 디렉토리 (필수)
- `--from <path>` — 수정된 domain-spec.yaml (필수)
- `--persona <level>` — junior | mid | senior | lead (기본: senior)
- `--language <lang>` — ko | en (기본: ko)
- `--dry-run` — 변경 사항만 보여주고 실제 쓰기 안 함
- `--adapters <list>` — 쉼표 구분 어댑터 (기본: claude-code,openclaw,generic)

### Step 3: 결과 확인

sync 결과에서 확인할 것:
- **preserved** — 기존 SKILL.md가 보존된 수
- **new** — 새로 scaffold된 스킬 수 (있으면 SKILL.md 채우기 필요)
- **orphaned** — domain-spec에서 빠졌지만 캠프에 남아있는 스킬 (수동 삭제 필요 시 안내)

### Step 4: 새 스킬 채우기 (있는 경우)

새로 scaffold된 스킬이 있으면 `camp-create` 스킬의 Step 5와 동일하게 SKILL.md를 채운다.

### Step 5: 검증

`camp-validate` 스킬로 전체 캠프를 검증한다.

## Output Format

```
=== CampForge: Syncing camp "my-domain" ===

[1/5] Syncing identity files...
[2/5] Syncing knowledge & dependencies...
[3/5] Syncing adapters & tests...
[4/5] Checking skills...
  my-skill: exists — skipped
  new-skill: new — scaffolded
[5/5] Writing manifest...
Sync complete: 1 skills preserved, 1 new, 0 orphaned
```

## Stop Conditions

- sync 완료 및 검증 통과
- 사용자가 dry-run 확인 후 중단 요청
- CLI 오류 — 에러 메시지 보여주고 수정 방법 안내
