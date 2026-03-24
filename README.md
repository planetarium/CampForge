# CampForge

Agent Bootcamp Meta-Generator — 도메인별 에이전트 온보딩 패키지를 만드는 도구.

```
CampForge(domain_spec) → Bootcamp Repo → Agent에 설치
```

## Bootcamps

| Bootcamp | Domain | Skills |
|----------|--------|--------|
| [campforge-v8-admin](./campforge-v8-admin/) | V8 플랫폼 관리 | v8-admin (유저, 크레딧, 버스, 댓글) |
| [campforge-9c-backoffice](./campforge-9c-backoffice/) | Nine Chronicles 테이블 패치 | 9c-backoffice (validate → sign → stage → poll → upload → purge) |
| [campforge-iap-manager](./campforge-iap-manager/) | IAP 상품 관리 | iap-product-query, iap-product-import, iap-receipt-query, iap-asset-import, iap-image-upload |

## Quick Install

```bash
git clone https://github.com/planetarium/CampForge
cd CampForge/campforge-v8-admin && ./campforge-cli.sh
```

`campforge-cli.sh`가 플랫폼을 자동 감지하고 (Claude Code / OpenClaw / Generic) 적절한 어댑터로 설치합니다.

## CLI

새 부트캠프 생성, 검증, skill 추가를 위한 CLI.

```bash
cd cli && npm install

# 부트캠프 생성 (domain spec YAML → scaffold)
./node_modules/.bin/tsx bin/campforge.ts create --from ../domains/iap-manager.yaml

# 부트캠프 검증
./node_modules/.bin/tsx bin/campforge.ts validate ../campforge-v8-admin

# skill 추가
./node_modules/.bin/tsx bin/campforge.ts add-skill --bootcamp ../campforge-v8-admin --skill new-skill
```

CLI는 구조(scaffold)만 생성합니다. SKILL.md의 내용은 LLM이 채웁니다.

## Interview Mode

LLM에게 interview skill을 로드시키면 대화형으로 부트캠프를 만들 수 있습니다.

```
"새 부트캠프 만들어줘"
→ LLM이 질문 → domain-spec.yaml 작성 → campforge create → SKILL.md 채우기
```

[Interview Skill](./skills/interview/SKILL.md)

## Bootcamp Structure

```
campforge-{domain}/
├── manifest.yaml              # 메타데이터, 의존성, 호환성
├── package.json               # skill 의존성 (skillpm/npm)
├── campforge-cli.sh           # 원샷 설치
├── identity/                  # 에이전트 정체성
│   ├── SOUL.md                # 성격, 가치관, 톤
│   ├── IDENTITY.md            # 이름, 역할
│   └── AGENTS.md              # 운영 규칙, 에러 핸들링
├── skills/                    # AgentSkills 호환
│   └── {skill-name}/SKILL.md
├── knowledge/                 # 도메인 지식
│   ├── glossary.md
│   └── decision-trees/
├── adapters/                  # 플랫폼별 설치
│   ├── claude-code/install.sh
│   ├── openclaw/install.sh
│   └── generic/install.sh
└── tests/                     # 검증 시나리오
    ├── smoke-test.md
    └── scenarios/
```

## Platform Support

| Platform | Status |
|----------|--------|
| Claude Code | Supported |
| OpenClaw | Supported |
| Codex | Supported |
| Gemini CLI | Supported |
| Generic | Fallback |

## Shared Dependencies

[`@campforge/gql-ops`](./packages/gql-ops/) — GraphQL 기반 skill들의 공유 인프라 (gq CLI 호출 규약, 스키마 조회, self-healing).

## License

Apache-2.0
