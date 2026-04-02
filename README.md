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

A camp is agent-agnostic — each camp's `install.sh` handles installation via [skillpm](https://skillpm.dev/) across Claude Code, OpenClaw, Codex, Gemini CLI, and others.

## Available Camps

| Camp | Domain | Skills |
|----------|--------|--------|
| [v8-admin](./camps/v8-admin/) | V8 Platform Admin | v8-admin, gql-ops, gws-sheets |
| [9c-backoffice](./camps/9c-backoffice/) | Nine Chronicles Table Patch | 9c-backoffice, gql-ops |
| [iap-manager](./camps/iap-manager/) | IAP Product Management | iap-product-query, iap-product-import, iap-receipt-query, iap-asset-import, iap-image-upload, gql-ops |
| [campforge-guide](./camps/campforge-guide/) | CampForge Usage Guide | camp-create, camp-validate, camp-add-skill, camp-sync, camp-bench, campforge-interview |

---

## For Camp Users

### Install a Camp

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/v8-admin/install.sh | bash
```

This uses [skillpm](https://skillpm.dev/) + GitHub Release tarballs to install skills. Set `CAMPFORGE_VERSION` to pin a specific release, or `WORKSPACE` to choose the install directory.

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
export V8_SKILL_DIR="<path to v8-admin skill directory>"  # for --queryFile paths
```

**9c-backoffice:**
```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<your API key>"
export BO_SKILL_DIR="<path to 9c-backoffice skill directory>"  # for --queryFile paths
```

**iap-manager:**
```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<your API key>"
```

### Verify Installation

```
"smoke test를 실행해줘"
```

Each camp includes a smoke test (`tests/smoke-test.md`) that validates all skills are working.

---

## For Camp Creators

### Option 1: Interactive Interview

Load the [interview skill](./packages/campforge-interview/) into your LLM and say:

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
  --from domain-spec.yaml \
  --persona senior \
  --language ko
```

This generates a camp scaffold (identity, tests). Skills are created as separate packages in `packages/` and referenced from the camp's `package.json`.

**Validate** a camp:

```bash
./node_modules/.bin/tsx bin/campforge.ts validate ../camps/v8-admin
```

**Add a skill** to an existing camp:

```bash
./node_modules/.bin/tsx bin/campforge.ts add-skill \
  --camp ../camps/v8-admin \
  --skill cost-analyzer \
  --description "Analyze cloud infrastructure costs"
```

### Option 3: Manual

1. Create a camp directory with identity files (`identity/SOUL.md`, `IDENTITY.md`, `AGENTS.md`)
2. Create skill packages in `packages/{skill-name}/` following [AgentSkills](https://agentskills.io) format
3. Add domain knowledge to `knowledge/`
4. Add skill dependencies to the camp's `package.json`
5. Run `campforge validate` to check structure

---

## Repository Structure

```
CampForge/
├── packages/                  # All skill packages (resolved via skillpm)
│   ├── gql-ops/               #   Shared: GraphQL operations
│   ├── gws-sheets/            #   Shared: Google Sheets operations
│   ├── v8-admin/              #   V8 platform admin
│   ├── 9c-backoffice/         #   Nine Chronicles table patch
│   ├── iap-*/                 #   IAP management (5 packages)
│   ├── camp-*/                #   CampForge guide (5 packages)
│   └── campforge-interview/   #   Camp creation interview
├── camps/                     # Camp definitions (no skill code)
│   ├── v8-admin/
│   ├── 9c-backoffice/
│   ├── iap-manager/
│   └── campforge-guide/
├── cli/                       # CampForge CLI
├── scripts/                   # Release & install tooling
│   ├── release-pack.sh        #   Pack tarballs for GitHub Release
│   └── install-common.sh      #   Shared install functions (gws, etc.)
└── package.json               # npm workspaces root
```

## Camp Structure

A camp contains no skill code — skills are pulled in via [skillpm](https://skillpm.dev/) from `packages/`.

```
camps/{domain}/
├── manifest.yaml              # Metadata, skill references, compatibility
├── package.json               # Skill dependencies (@campforge/* packages)
├── install.sh                 # Installer (skillpm + release tarballs)
├── identity/                  # Agent identity
│   ├── SOUL.md
│   ├── IDENTITY.md
│   └── AGENTS.md
├── knowledge/                 # Domain knowledge
│   ├── glossary.md
│   └── decision-trees/
└── tests/
    ├── smoke-test.md
    └── scenarios/
```

## Skill Package Structure

```
packages/{skill-name}/
├── package.json               # Name, version, skill dependencies
└── skills/{skill-name}/
    ├── SKILL.md               # AgentSkills skill definition
    ├── queries/               # (optional) GraphQL query files
    └── references/            # (optional) API docs, examples
```

## Skill Packages

| Package | Description | Used by |
|---------|-------------|---------|
| [`@campforge/gql-ops`](./packages/gql-ops/) | GraphQL operations — gq CLI, schema introspection, self-healing | v8-admin, 9c-backoffice, iap-manager |
| [`@campforge/gws-sheets`](./packages/gws-sheets/) | Google Sheets operations via gws CLI | v8-admin |
| [`@campforge/v8-admin`](./packages/v8-admin/) | V8 platform admin — users, credits, verses, comments | v8-admin |
| [`@campforge/9c-backoffice`](./packages/9c-backoffice/) | Nine Chronicles table patch operations | 9c-backoffice |
| `@campforge/iap-*` | IAP product/receipt/asset management (5 packages) | iap-manager |
| `@campforge/camp-*` | CampForge guide skills (5 packages) | campforge-guide |
| [`@campforge/campforge-interview`](./packages/campforge-interview/) | Interactive camp creation via guided interview | campforge-guide |

## Releasing

```bash
# 1. Pack all skill packages into tarballs
bash scripts/release-pack.sh

# 2. Create a GitHub Release with all tarballs
gh release create v1.0.0 dist/tarballs/*.tgz
```

Camps reference these tarballs in `install.sh` for installation without npm publish.

## Platform Support

| Platform | Identity | Skills | Heartbeat |
|----------|----------|--------|-----------|
| Claude Code | CLAUDE.md (merged) | .claude/skills/ | — |
| OpenClaw | SOUL.md, AGENTS.md | workspace/skills/ | Supported |
| Codex | AGENTS.md (merged) | .codex/skills/ | — |
| Gemini CLI | — | .gemini/skills/ | — |
| Generic | — | .agents/skills/ | — |

## License

Apache-2.0
