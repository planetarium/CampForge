import Handlebars from "handlebars";
import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import type { PipelineContext } from "../commands/create.js";

const soulTemplate = Handlebars.compile(`# Soul

You are the **{{name}} Agent** — {{role_template}}

## Core Values

{{#each core_values}}
- **{{this}}**
{{/each}}

## Tone

{{tone_description}}
{{language_note}}

## Boundaries

{{#each boundaries}}
- {{this}}
{{/each}}
`);

const identityTemplate = Handlebars.compile(`# Identity

- **Name**: {{name}} Agent
- **Role**: {{role_description}}
- **Domain**: {{domain_name}}
- **Primary Tools**: gq (graphqurl), GraphQL API
`);

const agentsTemplate = Handlebars.compile(`# Operating Rules

## Startup

1. Check required environment variables — ask user if not set
2. Do NOT introspect schema upfront (token optimization)

## Workflow Rules

{{#each rules}}
- {{this}}
{{/each}}

## Error Handling

1. GraphQL error → follow gql-ops self-healing procedure
2. Authentication error → request new credentials from user
3. Unknown error → report to user with full context
`);

const TONE_MAP: Record<string, string> = {
  friendly: "Friendly and approachable. Explains actions clearly.",
  direct: "Direct and professional. Focuses on operational tasks with minimal explanation.",
  formal: "Formal and structured. Uses precise language.",
  casual: "Casual and conversational. Keeps things simple.",
};

export function generateIdentity(ctx: PipelineContext): void {
  const { domainSpec, persona, language } = ctx;
  const d = domainSpec.domain;
  const dir = join(ctx.outputDir, "identity");

  const levelRules = d.identity.levels?.[persona]?.append_rules || [];
  const allRules = [...d.identity.boundaries, ...levelRules];

  const tone = persona === "lead" ? "direct" : persona === "junior" ? "friendly" : "direct";
  const roleTemplate = d.identity.role_template.replace("{level}", persona);

  writeFile(
    join(dir, "SOUL.md"),
    soulTemplate({
      name: d.name,
      role_template: roleTemplate,
      core_values: d.identity.core_values,
      boundaries: d.identity.boundaries,
      tone_description: TONE_MAP[tone] || TONE_MAP.direct,
      language_note: language !== "en" ? `Supports both Korean and English.` : "",
    })
  );

  writeFile(
    join(dir, "IDENTITY.md"),
    identityTemplate({
      name: d.name,
      role_description: roleTemplate,
      domain_name: d.name,
    })
  );

  writeFile(
    join(dir, "AGENTS.md"),
    agentsTemplate({ rules: allRules })
  );
}
