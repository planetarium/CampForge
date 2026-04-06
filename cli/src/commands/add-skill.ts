import { Command } from "commander";
import { resolve, join } from "node:path";
import { readFileSync, writeFileSync } from "node:fs";
import * as yaml from "js-yaml";
import { log } from "../utils/logger.js";
import { exists, writeFile } from "../utils/fs.js";
import { findRepoRoot } from "../utils/repo.js";

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
      const repoRoot = findRepoRoot(campDir);
      const pkgDir = join(repoRoot, "packages", skillId);
      const skillDir = join(pkgDir, "skills", skillId);
      const description = opts.description || `${skillId} skill`;

      if (exists(join(pkgDir, "package.json"))) {
        log.warn(`packages/${skillId}/package.json already exists — skipping scaffold`);
      } else {
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
        const pkg = {
          name: `@campforge/${skillId}`,
          version: "0.1.0",
          description,
          keywords: ["agent-skill", ...skillId.split("-"), "campforge"],
          license: "Apache-2.0",
          files: ["skills/"],
        };
        writeFile(join(pkgDir, "package.json"), JSON.stringify(pkg, null, 2) + "\n");
        log.info(`Scaffold created at packages/${skillId}/`);
      }

      // Add to camp package.json dependencies
      const campPkgPath = join(campDir, "package.json");
      if (exists(campPkgPath)) {
        const campPkg = JSON.parse(readFileSync(campPkgPath, "utf-8"));
        campPkg.dependencies = campPkg.dependencies || {};
        campPkg.dependencies[`@campforge/${skillId}`] = "^0.1.0";
        writeFileSync(campPkgPath, JSON.stringify(campPkg, null, 2) + "\n", "utf-8");
      }
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
