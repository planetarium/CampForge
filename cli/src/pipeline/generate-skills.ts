import { join } from "node:path";
import { writeFile, exists } from "../utils/fs.js";
import { log } from "../utils/logger.js";
import { findRepoRoot } from "../utils/repo.js";
import type { PipelineContext } from "../commands/create.js";
import type { SkillSpec } from "../schema/domain-spec.js";

export function generateSkills(ctx: PipelineContext): void {
  const { domainSpec, outputDir, extras } = ctx;
  const repoRoot = findRepoRoot(outputDir);
  const allSkills = [
    ...domainSpec.domain.curriculum.core,
    ...(domainSpec.domain.curriculum.elective || []).filter(
      (s) => extras.includes(s.skill_id)
    ),
  ];

  for (const skill of allSkills) {
    switch (skill.source) {
      case "generate": {
        scaffoldPackage(skill, repoRoot);
        break;
      }
      case "reference":
        log.info(`  ${skill.skill_id}: reference → package.json`);
        break;
      case "fork": {
        if (skill.ref) {
          log.info(`  ${skill.skill_id}: fork from ${skill.ref}`);
          scaffoldPackage(skill, repoRoot);
        }
        break;
      }
    }
  }
}

/**
 * Scaffold a skill as an independent package under packages/.
 * Returns true if scaffolded, false if skipped (already exists).
 */
export function scaffoldPackage(skill: SkillSpec, repoRoot: string): boolean {
  const pkgDir = join(repoRoot, "packages", skill.skill_id);
  const pkgJsonPath = join(pkgDir, "package.json");

  if (exists(pkgJsonPath)) {
    log.warn(`  ${skill.skill_id}: packages/${skill.skill_id}/package.json already exists — skipping`);
    return false;
  }

  const skillDir = join(pkgDir, "skills", skill.skill_id);
  writeScaffold(skill, skillDir);
  writePackageJson(skill, pkgDir);
  log.info(`  ${skill.skill_id}: scaffolded in packages/ (fill in with LLM)`);
  return true;
}

function writePackageJson(skill: SkillSpec, pkgDir: string): void {
  const desc = skill.spec?.description || `${skill.skill_id} skill`;
  const pkg = {
    name: `@campforge/${skill.skill_id}`,
    version: "0.1.0",
    description: desc,
    keywords: ["agent-skill", ...skill.skill_id.split("-"), "campforge"],
    license: "Apache-2.0",
    files: ["skills/"],
  };
  writeFile(join(pkgDir, "package.json"), JSON.stringify(pkg, null, 2) + "\n");
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
