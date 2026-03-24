import { Command } from "commander";
import { resolve, join } from "node:path";
import { readFileSync, writeFileSync } from "node:fs";
import * as yaml from "js-yaml";
import { log } from "../utils/logger.js";
import { exists, writeFile } from "../utils/fs.js";

export const addSkillCommand = new Command("add-skill")
  .description("Add a skill scaffold to an existing camp")
  .requiredOption("--camp <dir>", "Camp directory")
  .requiredOption("--skill <id>", "Skill ID")
  .option("--source <type>", "Source type: scaffold | reference", "scaffold")
  .option("--ref <ref>", "npm package reference (for reference source)")
  .option("--description <desc>", "Skill description")
  .action((opts) => {
    const campDir = resolve(opts.camp);
    const manifestPath = join(campDir, "manifest.yaml");

    if (!exists(manifestPath)) {
      log.error(`manifest.yaml not found in ${campDir}`);
      process.exit(1);
    }

    const manifest = yaml.load(readFileSync(manifestPath, "utf-8")) as any;
    const skillId: string = opts.skill;

    log.info(`Adding skill "${skillId}" to ${campDir}`);

    if (opts.source === "scaffold") {
      const skillDir = join(campDir, "skills", skillId);
      const description = opts.description || `${skillId} skill`;

      writeFile(
        join(skillDir, "SKILL.md"),
        `---
name: ${skillId}
description: "${description}"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# ${skillId}

## When to Use

${description}

## Workflow

TODO: Define workflow steps.

## Output Format

TODO: Define structured output format.

## Stop Conditions

- Task completed successfully
- Error encountered — report and stop
`
      );
      log.info(`Scaffold created at skills/${skillId}/SKILL.md`);
    } else if (opts.source === "reference") {
      if (!opts.ref) {
        log.error("--ref required for reference source");
        process.exit(1);
      }
      const pkgPath = join(campDir, "package.json");
      if (exists(pkgPath)) {
        const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
        pkg.dependencies = pkg.dependencies || {};
        pkg.dependencies[opts.ref] = "latest";
        writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n", "utf-8");
      }
      log.info(`Added ${opts.ref} to package.json`);
    }

    // Update manifest
    if (!manifest.camp.skills.optional.includes(skillId)) {
      manifest.camp.skills.optional.push(skillId);
      writeFileSync(manifestPath, yaml.dump(manifest, { lineWidth: 120 }), "utf-8");
      log.info(`Added "${skillId}" to manifest.yaml (optional)`);
    }

    log.success(`Skill "${skillId}" added — fill in SKILL.md with your LLM`);
  });
