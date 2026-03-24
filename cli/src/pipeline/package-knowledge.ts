import { join } from "node:path";
import { writeFile } from "../utils/fs.js";
import type { PipelineContext } from "../commands/create.js";

export function packageKnowledge(ctx: PipelineContext): void {
  const knowledge = ctx.domainSpec.domain.knowledge;
  if (!knowledge) return;

  const dir = join(ctx.outputDir, "knowledge");

  // Glossary
  if (knowledge.glossary && Object.keys(knowledge.glossary).length > 0) {
    const lines = [`# ${ctx.domainSpec.domain.name} Glossary\n`, "| Term | Definition |", "|------|-----------|"];
    for (const [term, def] of Object.entries(knowledge.glossary)) {
      lines.push(`| **${term}** | ${def} |`);
    }
    writeFile(join(dir, "glossary.md"), lines.join("\n") + "\n");
  }

  // Decision trees
  if (knowledge.decision_trees) {
    for (const tree of knowledge.decision_trees) {
      const slug = tree.name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
      const lines = [`# ${tree.name}\n`, "```"];
      for (const step of tree.tree) {
        lines.push(step);
      }
      lines.push("```\n");
      writeFile(join(dir, "decision-trees", `${slug}.md`), lines.join("\n"));
    }
  }
}
