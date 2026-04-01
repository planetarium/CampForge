import { join } from "node:path";
import * as yaml from "js-yaml";
import { writeFile } from "../utils/fs.js";
import type { PipelineContext } from "../commands/create.js";

export function writeManifest(ctx: PipelineContext): void {
  const { domainSpec, persona, language, outputDir, extras } = ctx;
  const d = domainSpec.domain;

  const toScoped = (id: string) => id.startsWith("@") ? id : `@campforge/${id}`;
  const coreSkills = d.curriculum.core.map((s) => toScoped(s.skill_id));
  const optionalSkills = (d.curriculum.elective || [])
    .map((s) => toScoped(s.skill_id))
    .filter((id) => !extras.map(toScoped).includes(id));
  const tools = [
    ...new Set(d.curriculum.core.flatMap((s) => s.spec?.tools_needed || [])),
  ];

  const manifest = {
    camp: {
      name: d.id,
      version: "1.0.0",
      spec_version: "camp/1.0",
      description: `${d.name} agent camp`,

      domain: {
        primary: d.id.split("-")[0],
        tags: d.id.split("-"),
      },

      persona: {
        level: persona,
        tone: "direct",
        proactivity: "medium",
        language,
      },

      skills: {
        required: coreSkills,
        optional: optionalSkills,
      },

      dependencies: {
        tools: tools.length > 0 ? tools : ["gq"],
        mcp_servers: [] as any[],
        skills: [{ "@campforge/gql-ops": "^0.2.0" }],
      },

      compatibility: {
        tested: [
          { platform: "claude-code", status: "pass" },
          { platform: "openclaw", status: "pass" },
        ],
        frontmatter_mode: "minimal",
      },
    },
  };

  writeFile(
    join(outputDir, "manifest.yaml"),
    yaml.dump(manifest, { lineWidth: 120 })
  );
}
