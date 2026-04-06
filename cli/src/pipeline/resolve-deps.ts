import { join } from "node:path";
import { readFileSync } from "node:fs";
import { writeFile, exists } from "../utils/fs.js";
import { findRepoRoot } from "../utils/repo.js";
import type { PipelineContext } from "../commands/create.js";

export function resolveDeps(ctx: PipelineContext): void {
  const { domainSpec, outputDir, extras, mode } = ctx;
  const electives = domainSpec.domain.curriculum.elective || [];
  // "create" filters electives by --extras; "sync" includes all to preserve deps
  const filteredElectives = mode === "sync"
    ? electives
    : electives.filter((s) => extras.includes(s.skill_id));
  const allSkills = [
    ...domainSpec.domain.curriculum.core,
    ...filteredElectives,
  ];

  const repoRoot = findRepoRoot(outputDir);

  // Collect dependencies from all skills
  const npmDeps: Record<string, string> = {};
  for (const skill of allSkills) {
    if (skill.source === "reference" && skill.ref) {
      // ref format: "clawhub:name" or "@scope/name"
      const pkgName = skill.ref.startsWith("@")
        ? skill.ref
        : `@campforge/${skill.ref.replace(/.*:/, "")}`;
      npmDeps[pkgName] = "latest";
    } else if (skill.source === "generate" || skill.source === "fork") {
      // Read actual version from existing package, fall back to ^0.1.0
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

function readSkillVersion(repoRoot: string, skillId: string): string {
  const pkgPath = join(repoRoot, "packages", skillId, "package.json");
  if (exists(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      if (typeof pkg.version === "string" && pkg.version.trim()) {
        return `^${pkg.version}`;
      }
    } catch {
      // invalid JSON, fall through
    }
  }
  return "^0.1.0";
}
