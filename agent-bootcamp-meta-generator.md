# CampForge — Agent Camp Meta-Generator

> 도메인별 에이전트 부트캠프 팩을 찍어내는 메타 제네레이터 설계
> AgentSkills 호환 — OpenClaw, Claude Code, Codex, Gemini CLI 등 범용

---

## 1. 개념 정의

### 부트캠프(Camp)란

에이전트가 특정 도메인에서 "즉시 쓸모있게" 되기 위한 초기 설정 패키지.

```
Camp = Identity(누구인가) + Curriculum(무엇을 알아야 하는가) + Toolkit(무엇을 할 수 있는가)
```

사람이 신입사원 온보딩 받는 것과 같은 메타포:
- **Identity** = 명함, 직책, 행동강령 → SOUL.md, IDENTITY.md, AGENTS.md
- **Curriculum** = 필수 교육, 도메인 지식 → Skills (SKILL.md 폴더들)
- **Toolkit** = 업무 도구 세팅, 권한 → Config preset, tool allowlist, MCP 연결

### 메타 제네레이터(Meta-Generator)란

부트캠프 자체를 "인스턴스"로 보고, 도메인 파라미터를 넣으면 부트캠프 저장소를 생성하는 시스템.

```
CampForge(domain_spec) → Camp Repo → Agent에 적용
```

---

## 2. 아키텍처

```
┌─────────────────────────────────────────────────┐
│              CampForge CLI/API                   │
│  campforge create --domain "devops-sre"          │
│              --persona "senior"                  │
│              --channels "slack,telegram"          │
└───────────────────────┬─────────────────────────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
   ┌────────────┐ ┌──────────┐ ┌──────────────┐
   │  Domain    │ │ Persona  │ │  Platform    │
   │  Registry  │ │ Templates│ │  Adapters    │
   │            │ │          │ │              │
   │ devops-sre │ │ senior   │ │ openclaw     │
   │ pm         │ │ junior   │ │ claude-code  │
   │ content    │ │ lead     │ │ codex        │
   │ security   │ │ solo     │ │ gemini-cli   │
   │ research   │ │          │ │ cursor       │
   └─────┬──────┘ └────┬─────┘ └──────┬───────┘
         │              │              │
         └──────────────┼──────────────┘
                        ▼
              ┌──────────────────┐
              │  Camp Repo   │
              │  (Git artifact)  │
              └──────────────────┘
```

### 생성되는 Camp Repo 구조

```
camp-devops-sre/
├── manifest.yaml              # 부트캠프 메타데이터
├── identity/                  # 퍼스널라이즈 레이어 (agent-agnostic)
│   ├── SOUL.md                # 성격, 톤, 가치관
│   ├── IDENTITY.md            # 이름, 역할, 목표
│   ├── AGENTS.md              # 절차적 규칙, 워크플로우
│   ├── USER.template.md       # 사용자 정보 (placeholder)
│   └── HEARTBEAT.md           # 주기적 체크 (해당 시)
│
├── skills/                    # AgentSkills 스펙 호환
│   ├── infra-health-check/
│   │   └── SKILL.md
│   ├── incident-response/
│   │   └── SKILL.md
│   ├── deploy-checklist/
│   │   └── SKILL.md
│   ├── log-analysis/
│   │   └── SKILL.md
│   └── runbook-executor/
│       ├── SKILL.md
│       └── scripts/           # 선택적 helper scripts
│
├── knowledge/                 # 도메인 참조 자료
│   ├── glossary.md
│   ├── decision-trees/
│   └── templates/
│
├── adapters/                  # 플랫폼별 설치 로직
│   ├── openclaw/
│   │   ├── install.sh
│   │   ├── config-patch.json  # openclaw.json에 머지할 조각
│   │   └── skills-map.yaml    # skill → openclaw skill entry 매핑
│   ├── claude-code/
│   │   ├── install.sh
│   │   └── CLAUDE.md          # identity → CLAUDE.md 변환
│   ├── codex/
│   │   ├── install.sh
│   │   └── agents-map.yaml
│   └── generic/
│       └── install.sh         # fallback: skills만 복사
│
├── tests/                     # 부트캠프 검증
│   ├── smoke-test.md          # 에이전트에게 주는 셀프 테스트 skill
│   └── scenarios/             # 도메인별 시나리오
│       ├── 01-basic-query.md
│       └── 02-incident-drill.md
│
└── campforge-cli.sh            # 원샷 설치 스크립트
    # 1. 에이전트 종류 자동 감지
    # 2. adapters/{agent}/install.sh 실행
    # 3. smoke-test 실행
```

---

## 3. manifest.yaml 스펙

```yaml
camp:
  name: "devops-sre"
  version: "1.0.0"
  spec_version: "camp/1.0"
  description: "DevOps/SRE 도메인 에이전트 부트캠프"
  
  # 도메인 태그 (검색/분류용)
  domain:
    primary: "devops"
    tags: ["sre", "infrastructure", "monitoring", "incident-response"]
  
  # 페르소나 프리셋
  persona:
    level: "senior"          # junior | mid | senior | lead
    tone: "direct"           # friendly | direct | formal | casual
    proactivity: "high"      # low | medium | high
    language: "en"           # 기본 언어
  
  # 포함된 skills
  skills:
    required:
      - infra-health-check
      - incident-response
      - deploy-checklist
    optional:
      - log-analysis
      - runbook-executor
      - cost-optimizer
  
  # 의존성
  dependencies:
    tools:                   # 시스템에 있어야 할 CLI
      - kubectl
      - docker
      - terraform
    mcp_servers:             # 연결하면 좋은 MCP 서버
      - name: "github"
        url: "https://github.mcp.example.com"
        required: false
    skills:                  # npm 호환 skill 패키지 (skillpm으로 해결)
      - "@camp-base/web-research": "^1.0.0"
  
  # 플랫폼 호환성
  compatibility:
    tested:
      - platform: "openclaw"
        version: ">=2026.2.0"
        status: "pass"
      - platform: "claude-code"
        status: "pass"
      - platform: "codex"
        status: "partial"
        notes: "heartbeat 미지원"
    frontmatter_mode: "minimal"   # AgentSkills 최대 호환
```

---

## 4. Domain Registry: 도메인 정의 스펙

메타 제네레이터의 입력. 도메인별로 하나씩.

```yaml
# domains/devops-sre.yaml
domain:
  id: "devops-sre"
  name: "DevOps / Site Reliability Engineering"
  
  # Identity 생성 가이드
  identity:
    role_template: >
      You are a {level} SRE agent. Your primary responsibility is
      maintaining system reliability, responding to incidents, and
      automating operational toil.
    core_values:
      - "Reliability over speed"
      - "Automate repetitive tasks"
      - "Blameless postmortems"
      - "Measure everything"
    boundaries:
      - "Never execute destructive commands without explicit confirmation"
      - "Always check current state before making changes"
      - "Escalate if blast radius is unclear"
    
    # 레벨별 오버라이드
    levels:
      junior:
        append_rules:
          - "Always explain what you're about to do before doing it"
          - "Ask for approval on any production change"
      senior:
        append_rules:
          - "Proactively identify reliability risks"
          - "Suggest architecture improvements"
      lead:
        append_rules:
          - "Coordinate across teams during incidents"
          - "Mentor junior team members"
  
  # Skill 커리큘럼
  curriculum:
    # 필수 skills — 제네레이터가 생성하거나 기존 skill 참조
    core:
      - skill_id: "infra-health-check"
        source: "generate"        # generate | reference | fork
        spec:
          description: "Check infrastructure health across k8s, cloud, and monitoring."
          workflow:
            - "Check k8s cluster health (kubectl get nodes, pods)"
            - "Verify monitoring alerts (Prometheus/Grafana/Datadog)"
            - "Check recent deployments and their status"
            - "Report summary with severity levels"
          tools_needed: ["kubectl", "curl"]
      
      - skill_id: "incident-response"
        source: "generate"
        spec:
          description: "Structured incident response following SRE best practices."
          workflow:
            - "Acknowledge incident and classify severity (SEV1-4)"
            - "Identify affected services and blast radius"
            - "Check recent changes (deploys, config changes)"
            - "Suggest mitigation steps"
            - "Draft incident communication"
            - "Create postmortem template when resolved"
          tools_needed: ["kubectl", "curl"]
    
    # 선택 skills — 활성화 여부는 사용자 선택
    elective:
      - skill_id: "cost-optimizer"
        source: "reference"
        ref: "clawhub:cloud-cost-optimizer"   # 기존 ClawHub skill 참조
      
      - skill_id: "terraform-assistant"
        source: "fork"
        ref: "github:hashicorp/terraform-skill"
        modifications:
          - "Add company-specific module conventions"
  
  # 도메인 지식
  knowledge:
    glossary:
      SLO: "Service Level Objective — target reliability percentage"
      SLI: "Service Level Indicator — metric measuring reliability"
      Error Budget: "Allowed unreliability = 1 - SLO"
      Toil: "Repetitive, automatable operational work"
    decision_trees:
      - name: "Incident Severity Classification"
        tree:
          - "User-facing impact? → SEV1 or SEV2"
          - "Data loss risk? → SEV1"
          - "Single service, workaround exists? → SEV3"
          - "Non-urgent, no immediate impact? → SEV4"
  
  # Heartbeat (주기적 태스크) — OpenClaw 등 지원 에이전트용
  heartbeat:
    checks:
      - name: "Morning infra scan"
        schedule: "0 9 * * *"
        action: "Run infra-health-check, report anomalies"
      - name: "Deploy watch"
        schedule: "*/30 * * * *"
        action: "Check for new deployments, verify health"
  
  # 테스트 시나리오
  test_scenarios:
    - name: "Basic health check"
      prompt: "Check the health of our infrastructure"
      expect: "Uses infra-health-check skill, reports structured output"
    - name: "Incident triage"
      prompt: "We're getting 500 errors on the API. What should we do?"
      expect: "Follows incident-response workflow, asks for severity"
```

---

## 5. Platform Adapters

### 어댑터가 하는 일

```
Identity files → 타겟 에이전트의 persona 설정으로 변환
Skills → 타겟 에이전트의 skill 디렉토리에 설치
Config → 타겟 에이전트의 설정에 머지
Heartbeat → 지원 시 cron/heartbeat 등록, 미지원 시 스킵
```

### 매핑 테이블

| Source | OpenClaw | Claude Code | Codex | Generic |
|--------|----------|-------------|-------|---------|
| `identity/SOUL.md` | `~/.openclaw/workspace/SOUL.md` | `.claude/CLAUDE.md` (합성) | `.codex/AGENTS.md` (합성) | `skills/identity/SKILL.md` |
| `identity/AGENTS.md` | `~/.openclaw/workspace/AGENTS.md` | `.claude/CLAUDE.md` (append) | `.codex/AGENTS.md` | `skills/workflow/SKILL.md` |
| `identity/USER.md` | `~/.openclaw/workspace/USER.md` | 해당 없음 (사용자 정보는 대화로) | 해당 없음 | 스킵 |
| `identity/HEARTBEAT.md` | `~/.openclaw/workspace/HEARTBEAT.md` | 스킵 (CLI 에이전트) | 스킵 | 스킵 |
| `skills/*` | `~/.openclaw/skills/*` | `.claude/skills/*` | `.codex/skills/*` | `.agents/skills/*` |
| `config-patch` | `openclaw.json` merge | `settings.json` merge | `.codex/config` merge | 스킵 |

### Claude Code 어댑터 예시

```bash
#!/bin/bash
# adapters/claude-code/install.sh

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_DIR="${1:-.}"  # 프로젝트 디렉토리

# 1. Skills 복사
mkdir -p "$TARGET_DIR/.claude/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/$skill_name"
done

# 2. Identity → CLAUDE.md 합성
{
  echo "# Agent Identity"
  echo ""
  cat "$CAMP_DIR/identity/SOUL.md"
  echo ""
  echo "# Operating Rules"
  echo ""
  cat "$CAMP_DIR/identity/AGENTS.md"
} > "$TARGET_DIR/.claude/CLAUDE.md"

# 3. Knowledge → context로 복사
if [ -d "$CAMP_DIR/knowledge" ]; then
  cp -r "$CAMP_DIR/knowledge" "$TARGET_DIR/.claude/knowledge"
fi

echo "✓ Camp installed for Claude Code"
echo "  Skills: $(ls "$TARGET_DIR/.claude/skills" | wc -l) installed"
echo "  Identity: .claude/CLAUDE.md created"
```

### OpenClaw 어댑터 예시

```bash
#!/bin/bash
# adapters/openclaw/install.sh

CAMP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

# 1. Identity 파일 복사 (백업 먼저)
for f in SOUL.md IDENTITY.md AGENTS.md HEARTBEAT.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    cp "$WORKSPACE/$f" "$WORKSPACE/$f.bak"
  fi
  if [ -f "$CAMP_DIR/identity/$f" ]; then
    cp "$CAMP_DIR/identity/$f" "$WORKSPACE/$f"
  fi
done

# 2. USER.md는 템플릿만 (기존 것 보존)
if [ ! -f "$WORKSPACE/USER.md" ] && [ -f "$CAMP_DIR/identity/USER.template.md" ]; then
  cp "$CAMP_DIR/identity/USER.template.md" "$WORKSPACE/USER.md"
fi

# 3. Skills 설치
mkdir -p "$WORKSPACE/skills"
for skill_dir in "$CAMP_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  cp -r "$skill_dir" "$WORKSPACE/skills/$skill_name"
done

# 4. Config 머지 (jq로 deep merge)
if [ -f "$CAMP_DIR/adapters/openclaw/config-patch.json" ]; then
  if command -v jq &> /dev/null; then
    jq -s '.[0] * .[1]' \
      "$HOME/.openclaw/openclaw.json" \
      "$CAMP_DIR/adapters/openclaw/config-patch.json" \
      > "$HOME/.openclaw/openclaw.json.tmp"
    mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"
  fi
fi

# 5. Gateway 재시작
if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>/dev/null || true
fi

echo "✓ Camp installed for OpenClaw"
```

---

## 6. Meta-Generator 워크플로우

### CLI 인터페이스

```bash
# 새 도메인 부트캠프 생성
campforge create \
  --domain devops-sre \
  --persona senior \
  --language ko \
  --output ./camp-devops-sre

# 기존 도메인 정의에서 생성
campforge create \
  --from domains/devops-sre.yaml \
  --persona lead \
  --extras cost-optimizer,terraform-assistant

# 인터랙티브 모드 (에이전트가 질문하며 도메인 정의 작성)
campforge interview

# 기존 부트캠프에 skill 추가
campforge add-skill \
  --camp ./camp-devops-sre \
  --skill clawhub:log-analysis

# 부트캠프 검증
campforge validate ./camp-devops-sre

# 부트캠프 퍼블리시
campforge publish ./camp-devops-sre --registry clawhub
```

### 생성 파이프라인

```
1. Domain Spec 로드 (YAML 또는 interview 결과)
     ↓
2. Identity 파일 생성
   - domain.identity.role_template + persona.level → SOUL.md
   - core_values + boundaries + level overrides → AGENTS.md
   - IDENTITY.md 골격 생성
   - USER.template.md (placeholder)
   - heartbeat.checks → HEARTBEAT.md
     ↓
3. Skill 생성/조립
   - source: "generate" → LLM으로 SKILL.md 초안 생성
   - source: "reference" → package.json에 npm 의존성 기록
   - source: "fork" → 원본 복사 + modifications 적용
     ↓
3-1. Skill 의존성 해결 (skillpm)
   - manifest.yaml의 dependencies.skills → package.json 생성
   - `skillpm install` → npm 해결 + skills/*/SKILL.md 스캔 + 와이어링
   - lockfile(package-lock.json)으로 재현 가능한 설치 보장
     ↓
4. Knowledge 자료 패키징
   - glossary → knowledge/glossary.md
   - decision_trees → knowledge/decision-trees/
     ↓
5. Platform Adapters 생성
   - 호환성 매트릭스 기반으로 어댑터 스캐폴드
   - config-patch 생성 (tools allowlist 등)
     ↓
6. Test 시나리오 생성
   - test_scenarios → tests/scenarios/*.md
   - smoke-test.md 생성
     ↓
7. manifest.yaml 작성
     ↓
8. Git repo 초기화 + README.md 생성
```

### LLM 활용 포인트

Skill 자동 생성 시 LLM을 사용하되, 구조는 강제:

```python
def generate_skill(skill_spec, domain_context):
    prompt = f"""
    Generate an AgentSkills-compatible SKILL.md for:
    
    Name: {skill_spec.skill_id}
    Description: {skill_spec.description}
    Domain: {domain_context.name}
    
    Workflow steps:
    {yaml.dump(skill_spec.workflow)}
    
    Required tools: {skill_spec.tools_needed}
    
    Output format (strict):
    ---
    name: {skill_spec.skill_id}
    description: <one-line description>
    ---
    
    # <Skill Name>
    
    ## When to Use
    <trigger conditions>
    
    ## Workflow
    <numbered deterministic steps>
    
    ## Output Format
    <structured output spec>
    
    ## Stop Conditions
    <when to stop or escalate>
    
    Rules:
    - Write like a 3am on-call runbook, not marketing copy
    - Each step must be executable, not descriptive
    - Include error handling for each step
    - Frontmatter must be minimal (name + description only)
    """
    return llm.generate(prompt)
```

---

## 7. 부트캠프 저장소 (Camp Registry)

### 구조

```
camp-registry/
├── domains/                    # 도메인 정의 모음
│   ├── devops-sre.yaml
│   ├── product-management.yaml
│   ├── content-creation.yaml
│   ├── security-analyst.yaml
│   ├── data-engineering.yaml
│   └── customer-support.yaml
│
├── personas/                   # 페르소나 프리셋
│   ├── junior.yaml
│   ├── senior.yaml
│   ├── lead.yaml
│   └── solo-founder.yaml
│
├── shared-skills/              # 도메인 간 공유 skills (npm 패키지로도 배포)
│   ├── web-research/           # → @camp-base/web-research
│   │   ├── skills/web-research/SKILL.md
│   │   └── package.json
│   ├── email-draft/            # → @camp-base/email-draft
│   │   ├── skills/email-draft/SKILL.md
│   │   └── package.json
│   ├── meeting-notes/SKILL.md
│   └── status-report/SKILL.md
│
├── generated/                  # 생성된 부트캠프들
│   ├── camp-devops-sre-senior/
│   ├── camp-pm-lead/
│   ├── camp-content-solo/
│   └── ...
│
└── meta-generator/             # 제네레이터 코드
    ├── src/
    ├── templates/
    └── package.json
```

### 배포 모델

```
# 1. Git clone (가장 단순)
git clone https://github.com/org/camp-devops-sre
cd camp-devops-sre && ./campforge-cli.sh

# 2. npx (Zero install)
npx @vicoop/camp install devops-sre --agent auto

# 3. ClawHub (OpenClaw 생태계)
clawdhub install camp-devops-sre

# 4. skillpm (npm 기반 skill 의존성 해결)
skillpm install @camp-devops-sre/infra-health-check
skillpm sync

# 5. URL 직접 (에이전트에게 말하기)
"이 URL의 부트캠프를 설치해줘: https://camp.vicoop.dev/devops-sre"
→ 에이전트가 fetch → manifest 읽기 → 자동 설치
```

---

## 8. ViCoop 통합

### A2A Agent Card 자동 발급

부트캠프 설치 완료 시, ViCoop 네트워크에 에이전트 등록:

```yaml
# 부트캠프 완료 후 자동 생성되는 Agent Card 초안
agent_card:
  name: "DevOps SRE Agent"
  description: "Infrastructure health monitoring and incident response"
  skills:
    - id: "infra-health-check"
      input_modes: ["text"]
      output_modes: ["text"]
    - id: "incident-response"
      input_modes: ["text"]
      output_modes: ["text"]
  authentication:
    schemes:
      - scheme: "oauth2"
        # ... ViCoop A2A auth config
  camp:
    source: "camp-devops-sre"
    version: "1.0.0"
    installed_at: "2026-03-23T12:00:00Z"
```

### PM Agent → Camp 연동

ViCoop PM Agent가 새 sub-agent 필요 시:

```
PM Agent: "인프라 모니터링 에이전트가 필요해"
     ↓
PM Agent → Camp Registry 검색 → "devops-sre" 매칭
     ↓
PM Agent → Code Agent에게 지시:
  "camp-devops-sre를 설치하고 ViCoop에 등록해줘"
     ↓
Code Agent: campforge-cli.sh 실행 → Agent Card 발급
     ↓
PM Agent: 새 에이전트에게 첫 태스크 할당
```

---

## 9. 구현 우선순위

### Phase 1: MVP (2주) ✓

- [x] Domain spec YAML 스키마 확정 (manifest.yaml)
- [x] Identity 파일 작성 (SOUL.md, IDENTITY.md, AGENTS.md) — 자동 생성은 Phase 2
- [x] Skills 복사/설치 로직 (gql-ops local fallback 포함)
- [x] OpenClaw + Claude Code + Generic 어댑터 3개
- [x] `campforge-cli.sh` 원샷 설치 스크립트
- [x] 2개 도메인 레퍼런스 구현 (v8-admin, 9c-backoffice)

### Phase 2: 제네레이터 (2주)

- [x] `campforge create` CLI (구조 스캐폴드 전담, LLM 미포함)
- [x] `campforge add-skill` CLI
- [x] LLM 역할 분리 — CLI는 구조만, LLM이 CLI를 도구로 사용하여 내용 채움
- [ ] skillpm 통합 (GitHub Packages private → `skillpm install` 연동)
- [x] Codex + Gemini CLI 어댑터 추가 (create 시 5개 자동 생성)
- [x] `campforge validate` 검증

### Phase 3: 레지스트리 + 자동화 (2주)

- [ ] Camp Registry (Git-based)
- [ ] `campforge interview` 인터랙티브 모드
- [ ] ViCoop A2A Agent Card 자동 발급
- [ ] ClawHub/Smithery 퍼블리시 연동
- [ ] smoke-test 자동 실행

### Phase 4: 네트워크 효과 (ongoing)

- [ ] 커뮤니티 도메인 기여 파이프라인
- [ ] 부트캠프 간 skill 의존성 관리 (skillpm 기반)
  - npm 레지스트리로 skill 배포 (`@camp-*` 네임스페이스)
  - `skillpm install/publish/sync` 통합
  - lockfile 기반 재현 가능한 설치
- [ ] 부트캠프 버전 업그레이드 (LLM 소프트 업그레이드)
  - 하드 머지(git merge 스타일) 없음 — 사용자 커스터마이즈 보호
  - `campforge upgrade` 워크플로우:
    1. 새 버전 diff 계산
    2. 사용자 커스터마이즈 감지 (원본 해시 대비)
    3. LLM이 변경사항을 커스터마이즈 컨텍스트에 맞게 적용 제안
    4. 사용자 확인 후 적용 (dry-run 기본)
- [ ] 사용 통계 기반 skill 품질 피드백 루프
