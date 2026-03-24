import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import type { PipelineContext } from "../commands/create.js";

export function generateTests(ctx: PipelineContext): void {
  const { domainSpec, outputDir } = ctx;
  const d = domainSpec.domain;

  // Smoke test
  const coreSkills = d.curriculum.core.map((s) => s.skill_id);
  const smokeLines = [
    "---",
    `name: ${d.id}-smoke-test`,
    `description: ${d.name} camp smoke test`,
    "---",
    "",
    `# ${d.name} Smoke Test`,
    "",
    "## Prerequisites",
    "",
    `- All skills loaded: ${coreSkills.join(", ")}`,
    "- Required environment variables set",
    "",
    "## Test Plan",
    "",
  ];

  for (const skill of coreSkills) {
    smokeLines.push(`### ${skill}`, "", `1. Verify skill loads correctly`, `2. Run basic operation`, "", "");
  }

  smokeLines.push(
    "## Report Format",
    "",
    "| Test | Result | Notes |",
    "|------|--------|-------|",
    ...coreSkills.map((s) => `| ${s} | PASS/FAIL | |`),
    ""
  );

  writeFile(join(outputDir, "tests", "smoke-test.md"), smokeLines.join("\n"));

  // Test scenarios from domain spec
  if (d.test_scenarios) {
    for (let i = 0; i < d.test_scenarios.length; i++) {
      const s = d.test_scenarios[i];
      const num = String(i + 1).padStart(2, "0");
      const slug = s.name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
      const content = [
        `# Scenario: ${s.name}`,
        "",
        "## Prompt",
        "",
        `"${s.prompt}"`,
        "",
        "## Expected Behavior",
        "",
        s.expect,
        "",
      ].join("\n");
      writeFile(join(outputDir, "tests", "scenarios", `${num}-${slug}.md`), content);
    }
  }
}
