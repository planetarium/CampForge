import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import type { PipelineContext } from "../commands/create.js";

export function resolveDeps(ctx: PipelineContext): void {
  const { domainSpec, outputDir } = ctx;
  const allSkills = [
    ...domainSpec.domain.curriculum.core,
    ...(domainSpec.domain.curriculum.elective || []),
  ];

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
      // Generated/forked skills are independent packages
      npmDeps[`@campforge/${skill.skill_id}`] = "^0.1.0";
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
