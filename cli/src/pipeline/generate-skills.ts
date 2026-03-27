import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import { log } from "../utils/logger.js";
import type { PipelineContext } from "../commands/create.js";
import type { SkillSpec } from "../schema/domain-spec.js";

export function generateSkills(ctx: PipelineContext): void {
  const { domainSpec, outputDir, extras } = ctx;
  const allSkills = [
    ...domainSpec.domain.curriculum.core,
    ...(domainSpec.domain.curriculum.elective || []).filter(
      (s) => extras.includes(s.skill_id)
    ),
  ];

  for (const skill of allSkills) {
    const skillDir = join(outputDir, "skills", skill.skill_id);

    switch (skill.source) {
      case "generate":
        writeScaffold(skill, skillDir);
        log.info(`  ${skill.skill_id}: scaffolded (fill in with LLM)`);
        break;
      case "reference":
        log.info(`  ${skill.skill_id}: reference → package.json`);
        break;
      case "fork":
        if (skill.ref) {
          log.info(`  ${skill.skill_id}: fork from ${skill.ref}`);
          writeScaffold(skill, skillDir);
        }
        break;
    }
  }
}

export function writeScaffold(skill: SkillSpec, skillDir: string): void {
  const desc = skill.spec?.description || `${skill.skill_id} skill`;
  const workflow = skill.spec?.workflow || [];

  writeFile(
    join(skillDir, "SKILL.md"),
    `---
name: ${skill.skill_id}
description: >
  ${desc}
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# ${skill.skill_id}

## When to Use

${desc}

## Workflow

${workflow.map((s, i) => `${i + 1}. ${s}`).join("\n")}

## Output Format

TODO: Define structured output format.

## Stop Conditions

- Task completed successfully
- Error encountered — report and stop
`
  );
}
