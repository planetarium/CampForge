import { Command } from "commander";
import { resolve, join } from "node:path";
import { readFileSync, writeFileSync } from "node:fs";
import * as yaml from "js-yaml";
import { log } from "../utils/logger.js";
import { exists } from "../utils/fs.js";
import { findRepoRoot } from "../utils/repo.js";
import { scaffoldPackage } from "../pipeline/generate-skills.js";

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
      const description = opts.description || `${skillId} skill`;

      scaffoldPackage(
        { skill_id: skillId, source: "generate", spec: { description, workflow: [], tools_needed: [] } },
        repoRoot,
      );

      // Add to camp package.json dependencies (preserve existing)
      const campPkgPath = join(campDir, "package.json");
      const depName = `@campforge/${skillId}`;
      if (exists(campPkgPath)) {
        const campPkg = JSON.parse(readFileSync(campPkgPath, "utf-8"));
        campPkg.dependencies = campPkg.dependencies || {};
        if (!Object.prototype.hasOwnProperty.call(campPkg.dependencies, depName)) {
          // Read actual version from scaffolded package, fall back to ^0.1.0
          let depVersion = "^0.1.0";
          const skillPkgPath = join(repoRoot, "packages", skillId, "package.json");
          if (exists(skillPkgPath)) {
            try {
              const skillPkg = JSON.parse(readFileSync(skillPkgPath, "utf-8"));
              if (typeof skillPkg.version === "string" && skillPkg.version.trim()) {
                depVersion = `^${skillPkg.version}`;
              }
            } catch { /* ignore */ }
          }
          campPkg.dependencies[depName] = depVersion;
          writeFileSync(campPkgPath, JSON.stringify(campPkg, null, 2) + "\n", "utf-8");
        }
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

    // Update manifest (use scoped name, initialize optional if missing)
    const scopedId = skillId.startsWith("@") ? skillId : `@campforge/${skillId}`;
    manifest.camp.skills.optional = manifest.camp.skills.optional || [];
    if (!manifest.camp.skills.optional.includes(scopedId)) {
      manifest.camp.skills.optional.push(scopedId);
      writeFileSync(manifestPath, yaml.dump(manifest, { lineWidth: 120 }), "utf-8");
      log.info(`Added "${scopedId}" to manifest.yaml (optional)`);
    }

    log.success(`Skill "${skillId}" added — fill in SKILL.md with your LLM`);
    log.warn(`Run "campforge sync" to regenerate install.sh with the new dependency.`);
  });
