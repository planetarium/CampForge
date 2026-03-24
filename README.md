# CampForge

Agent Camp Meta-Generator — a tool for creating domain-specific agent onboarding packages.

## What is a Camp?

A **Camp** is an onboarding package that makes an AI agent instantly useful in a specific domain. Think of it like employee onboarding — but for agents.

```
Camp = Identity (who am I?) + Skills (what can I do?) + Knowledge (what do I know?)
```

| Layer | Contents | Example |
|-------|----------|---------|
| **Identity** | Personality, values, operating rules | "You are a V8 Platform Admin Agent. Accuracy first." |
| **Skills** | Executable workflows ([AgentSkills](https://agentskills.io) format) | `v8-admin/SKILL.md` — user search, credit grant, comment management |
| **Knowledge** | Domain glossary, decision trees | "Credit amounts are in USD. Collection index 0 = Multiplayer." |

A camp is agent-agnostic — platform **adapters** handle installation across Claude Code, OpenClaw, Codex, Gemini CLI, and others.

```
CampForge(domain_spec) → Camp → Install on Agent
```

## Available Camps

| Camp | Domain | Skills |
|----------|--------|--------|
| [campforge-v8-admin](./camps/campforge-v8-admin/) | V8 Platform Admin | v8-admin (users, credits, verses, comments) |
| [campforge-9c-backoffice](./camps/campforge-9c-backoffice/) | Nine Chronicles Table Patch | 9c-backoffice (validate → sign → stage → poll → upload → purge) |
| [campforge-iap-manager](./camps/campforge-iap-manager/) | IAP Product Management | iap-product-query, iap-product-import, iap-receipt-query, iap-asset-import, iap-image-upload |

---

## For Camp Users

### Install a Camp

```bash
git clone https://github.com/planetarium/CampForge
cd CampForge/camps/campforge-v8-admin
./campforge-cli.sh
```

`campforge-cli.sh` auto-detects the platform (Claude Code / OpenClaw / Generic) and runs the appropriate adapter.

### What Gets Installed

| Platform | Identity | Skills | Knowledge |
|----------|----------|--------|-----------|
| **Claude Code** | `.claude/CLAUDE.md` | `.claude/skills/{skill}/` | `.claude/knowledge/` |
| **OpenClaw** | `~/.openclaw/workspace/SOUL.md` etc. | `~/.openclaw/workspace/skills/` | — |
| **Generic** | — | `.agents/skills/` | — |

### Post-Install: Set Environment Variables

Each camp requires specific environment variables. The agent will ask for them on first use, but you can set them upfront:

**v8-admin:**
```bash
export V8_GQL="https://planetarium-oag.fly.dev/v8-admin-test/graphql"
export V8_TOKEN="<your JWT>"
export V8_SKILL_DIR="<path to v8-admin skill>"
```

**9c-backoffice:**
```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<your API key>"
export BO_SKILL_DIR="<path to 9c-backoffice skill>"
```

**iap-manager:**
```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<your API key>"
```

### Using with Claude Code

After install, skills are automatically available. Just ask:

```
"V8에서 swen 유저를 검색해줘"
"오딘에 WorldSheet.csv 패치해줘"
"IAP 상품 목록을 보여줘"
```

### Using with OpenClaw

After install, the agent's identity and skills are loaded on gateway restart. Skills are invoked through natural conversation.

### Verify Installation

```
"smoke test를 실행해줘"
```

Each camp includes a smoke test (`tests/smoke-test.md`) that validates all skills are working.

---

## For Camp Creators

### Option 1: Interactive Interview

Load the [interview skill](./skills/interview/SKILL.md) into your LLM and say:

```
"Create a new camp"
```

The LLM will ask questions about your domain, write a `domain-spec.yaml`, run `campforge create`, and fill in the SKILL.md files.

### Option 2: CLI

```bash
cd cli && npm install
```

**Create a camp** from a domain spec YAML:

```bash
./node_modules/.bin/tsx bin/campforge.ts create \
  --from ../domains/iap-manager.yaml \
  --persona senior \
  --language ko
```

This generates a full camp scaffold (identity, skills, adapters, tests). The SKILL.md files contain placeholder content — have your LLM fill them in.

**Validate** a camp:

```bash
./node_modules/.bin/tsx bin/campforge.ts validate ../camps/campforge-v8-admin
```

**Add a skill** to an existing camp:

```bash
./node_modules/.bin/tsx bin/campforge.ts add-skill \
  --camp ../camps/campforge-v8-admin \
  --skill cost-analyzer \
  --description "Analyze cloud infrastructure costs"
```

### Option 3: Manual

Copy an existing camp directory and modify:

1. Edit `manifest.yaml` with your domain info
2. Write identity files (`identity/SOUL.md`, `IDENTITY.md`, `AGENTS.md`)
3. Create skills in `skills/{name}/SKILL.md` following [AgentSkills](https://agentskills.io) format
4. Add domain knowledge to `knowledge/`
5. Run `campforge validate` to check structure

### Domain Spec YAML

The input to `campforge create`. Defines the domain, identity, skills, and knowledge:

```yaml
domain:
  id: "my-domain"
  name: "My Domain"
  identity:
    role_template: "You are a {level} agent for ..."
    core_values: ["Accuracy first"]
    boundaries: ["Always confirm before changes"]
  curriculum:
    core:
      - skill_id: "my-skill"
        source: "generate"
        spec:
          description: "What this skill does"
          workflow: ["Step 1", "Step 2"]
          tools_needed: ["gq"]
  knowledge:
    glossary:
      Term: "Definition"
  test_scenarios:
    - name: "Basic test"
      prompt: "Do the thing"
      expect: "Uses my-skill correctly"
```

See [domains/](./domains/) for examples.

---

## Camp Structure

```
campforge-{domain}/
├── manifest.yaml              # Metadata, dependencies, compatibility
├── package.json               # Skill dependencies (skillpm/npm)
├── campforge-cli.sh           # One-shot install script
├── identity/                  # Agent identity
│   ├── SOUL.md                # Personality, values, tone
│   ├── IDENTITY.md            # Name, role
│   └── AGENTS.md              # Operating rules, error handling
├── skills/                    # AgentSkills compatible
│   └── {skill-name}/SKILL.md
├── knowledge/                 # Domain knowledge
│   ├── glossary.md
│   └── decision-trees/
├── adapters/                  # Platform-specific installers
│   ├── claude-code/install.sh
│   ├── openclaw/install.sh
│   └── generic/install.sh
└── tests/                     # Validation scenarios
    ├── smoke-test.md
    └── scenarios/
```

## Platform Support

| Platform | Identity | Skills | Heartbeat |
|----------|----------|--------|-----------|
| Claude Code | CLAUDE.md (merged) | .claude/skills/ | — |
| OpenClaw | SOUL.md, AGENTS.md | workspace/skills/ | Supported |
| Codex | AGENTS.md (merged) | .codex/skills/ | — |
| Gemini CLI | — | .gemini/skills/ | — |
| Generic | — | .agents/skills/ | — |

## Shared Dependencies

[`@campforge/gql-ops`](./packages/gql-ops/) — Shared infrastructure for GraphQL-based skills (gq CLI conventions, schema introspection, self-healing).

## License

Apache-2.0
