import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import { findRepoRoot } from "../utils/repo.js";
import { readSkillVersion } from "../utils/skill-version.js";
import type { PipelineContext } from "../commands/create.js";

/** Strip @campforge/ scope and trim whitespace from a skill ID */
function bareId(id: string): string {
  return id.replace(/^@campforge\//, "").trim();
}

export function resolveDeps(ctx: PipelineContext): void {
  const { domainSpec, outputDir, extras, mode } = ctx;
  const electives = domainSpec.domain.curriculum.elective || [];
  const normalizedExtras = extras.map(bareId);
  // "create" filters electives by --extras; "sync" includes all to preserve deps
  const filteredElectives = mode === "sync"
    ? electives
    : electives.filter((s) => normalizedExtras.includes(bareId(s.skill_id)));
  const allSkills = [
    ...domainSpec.domain.curriculum.core,
    ...filteredElectives,
  ];

  const repoRoot = findRepoRoot(outputDir);

  // Collect dependencies from all skills
  const npmDeps: Record<string, string> = {};
  for (const skill of allSkills) {
    if (skill.source === "reference" && skill.ref) {
      const pkgName = skill.ref.startsWith("@")
        ? skill.ref
        : `@campforge/${skill.ref.replace(/.*:/, "")}`;
      npmDeps[pkgName] = "latest";
    } else if (skill.source === "generate") {
      npmDeps[`@campforge/${skill.skill_id}`] = readSkillVersion(repoRoot, skill.skill_id);
    } else if (skill.source === "fork" && skill.ref) {
      npmDeps[`@campforge/${skill.skill_id}`] = readSkillVersion(repoRoot, skill.skill_id);
    }
  }

  const pkg = {
    name: `@campforge/camp-${domainSpec.domain.id}`,
    version: "1.0.0",
    description: `CampForge camp for ${domainSpec.domain.name}`,
    keywords: ["agent-skill", "campforge", ...domainSpec.domain.id.split("-")],
    license: "Apache-2.0",
    dependencies: npmDeps,
  };

  writeFile(join(outputDir, "package.json"), JSON.stringify(pkg, null, 2) + "\n");
}
