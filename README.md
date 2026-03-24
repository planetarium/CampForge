# CampForge

Agent Bootcamp Meta-Generator — a tool for creating domain-specific agent onboarding packages.

```
CampForge(domain_spec) → Bootcamp Repo → Install on Agent
```

## Bootcamps

| Bootcamp | Domain | Skills |
|----------|--------|--------|
| [campforge-v8-admin](./campforge-v8-admin/) | V8 Platform Admin | v8-admin (users, credits, verses, comments) |
| [campforge-9c-backoffice](./campforge-9c-backoffice/) | Nine Chronicles Table Patch | 9c-backoffice (validate → sign → stage → poll → upload → purge) |
| [campforge-iap-manager](./campforge-iap-manager/) | IAP Product Management | iap-product-query, iap-product-import, iap-receipt-query, iap-asset-import, iap-image-upload |

## Quick Install

```bash
git clone https://github.com/planetarium/CampForge
cd CampForge/campforge-v8-admin && ./campforge-cli.sh
```

`campforge-cli.sh` auto-detects the platform (Claude Code / OpenClaw / Generic) and runs the appropriate adapter.

## CLI

CLI for creating, validating, and extending bootcamps.

```bash
cd cli && npm install

# Create a bootcamp (domain spec YAML → scaffold)
./node_modules/.bin/tsx bin/campforge.ts create --from ../domains/iap-manager.yaml

# Validate a bootcamp
./node_modules/.bin/tsx bin/campforge.ts validate ../campforge-v8-admin

# Add a skill
./node_modules/.bin/tsx bin/campforge.ts add-skill --bootcamp ../campforge-v8-admin --skill new-skill
```

The CLI only generates structure (scaffold). An LLM fills in the SKILL.md content.

## Interview Mode

Load the interview skill into an LLM to create bootcamps interactively.

```
"Create a new bootcamp"
→ LLM asks questions → writes domain-spec.yaml → runs campforge create → fills in SKILL.md
```

[Interview Skill](./skills/interview/SKILL.md)

## Bootcamp Structure

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

| Platform | Status |
|----------|--------|
| Claude Code | Supported |
| OpenClaw | Supported |
| Codex | Supported |
| Gemini CLI | Supported |
| Generic | Fallback |

## Shared Dependencies

[`@campforge/gql-ops`](./packages/gql-ops/) — Shared infrastructure for GraphQL-based skills (gq CLI conventions, schema introspection, self-healing).

## License

Apache-2.0
