import { Command } from "commander";
import { resolve, join } from "node:path";
import { readFileSync } from "node:fs";
import { loadDomainSpec } from "../pipeline/load-domain-spec.js";
import { generateIdentity } from "../pipeline/generate-identity.js";
import { packageKnowledge } from "../pipeline/package-knowledge.js";
import { generateInstall } from "../pipeline/generate-install.js";
import { generateTests } from "../pipeline/generate-tests.js";
import { writeManifest } from "../pipeline/write-manifest.js";
import { resolveDeps } from "../pipeline/resolve-deps.js";
import { exists } from "../utils/fs.js";
import { log } from "../utils/logger.js";
import type { PipelineContext } from "./create.js";
import type { SkillSpec } from "../schema/domain-spec.js";
import * as yaml from "js-yaml";
import { ManifestSchema } from "../schema/manifest.js";
import { scaffoldPackage } from "../pipeline/generate-skills.js";
import { findRepoRoot } from "../utils/repo.js";

const TOTAL_STEPS = 5;

export const syncCommand = new Command("sync")
  .description("Sync domain-spec changes to an existing camp (preserves SKILL.md content)")
  .requiredOption("--camp <dir>", "Existing camp directory")
  .requiredOption("--from <path>", "Updated domain spec YAML file")
  .option("--persona <level>", "Persona level", "senior")
  .option("--language <lang>", "Language", "ko")
  .option("--dry-run", "Show what would change without writing files")
  .action((opts) => {
    const campDir = resolve(opts.camp);
    const specPath = resolve(opts.from);
    const dryRun: boolean = opts.dryRun || false;

    if (!exists(join(campDir, "manifest.yaml"))) {
      log.error(`manifest.yaml not found in ${campDir}`);
      process.exit(1);
    }

    const domainSpec = loadDomainSpec(specPath);
    const domainId = domainSpec.domain.id;

    console.log(
      `\n=== CampForge: Syncing camp "${domainId}" ===${dryRun ? " (dry-run)" : ""}\n`
    );

    const ctx: PipelineContext = {
      domainSpec,
      persona: opts.persona,
      language: opts.language,
      outputDir: campDir,
      extras: [],
    };

    // Load existing manifest to compare skills
    const oldManifest = ManifestSchema.parse(
      yaml.load(readFileSync(join(campDir, "manifest.yaml"), "utf-8"))
    );
    const oldSkills = [
      ...oldManifest.camp.skills.required,
      ...(oldManifest.camp.skills.optional || []),
    ];

    if (dryRun) {
      console.log("Would overwrite:");
      console.log("  identity/SOUL.md, IDENTITY.md, AGENTS.md");
      console.log("  knowledge/glossary.md");
      console.log("  manifest.yaml, package.json, install.sh");
      console.log("  tests/smoke-test.md");

      // Check for new skills
      const specSkills = [
        ...domainSpec.domain.curriculum.core,
        ...(domainSpec.domain.curriculum.elective || []),
      ];
      const dryRunRepoRoot = findRepoRoot(campDir);
      const newSkills = specSkills.filter(
        (s) => !exists(join(dryRunRepoRoot, "packages", s.skill_id, "skills", s.skill_id, "SKILL.md"))
      );
      const removedSkills = oldSkills.filter(
        (id) => !specSkills.some((s) => s.skill_id === id)
      );

      if (newSkills.length > 0) {
        console.log("\nWould scaffold new skills:");
        for (const s of newSkills) {
          console.log(`  + packages/${s.skill_id}/skills/${s.skill_id}/SKILL.md`);
        }
      }
      if (removedSkills.length > 0) {
        console.log("\nSkills in camp but not in domain-spec (not deleted):");
        for (const id of removedSkills) {
          log.warn(`  ${id} — remove manually if no longer needed`);
        }
      }

      console.log("\nWould NOT touch:");
      console.log("  packages/*/skills/*/SKILL.md (existing)");
      console.log("\nRun without --dry-run to apply.\n");
      return;
    }

    // Step 1: Regenerate identity
    log.step(1, TOTAL_STEPS, "Syncing identity files...");
    generateIdentity(ctx);

    // Step 2: Sync knowledge + deps + install script
    log.step(2, TOTAL_STEPS, "Syncing knowledge & dependencies...");
    packageKnowledge(ctx);
    resolveDeps(ctx);
    generateInstall(ctx);

    // Step 3: Sync tests
    log.step(3, TOTAL_STEPS, "Syncing tests...");
    generateTests(ctx);

    // Step 4: Scaffold new skills only
    log.step(4, TOTAL_STEPS, "Checking skills...");
    const specSkills = [
      ...domainSpec.domain.curriculum.core,
      ...(domainSpec.domain.curriculum.elective || []),
    ];

    const repoRoot = findRepoRoot(campDir);
    let newCount = 0;
    let skippedCount = 0;
    for (const skill of specSkills) {
      const skillMd = join(repoRoot, "packages", skill.skill_id, "skills", skill.skill_id, "SKILL.md");
      if (exists(skillMd)) {
        log.info(`  ${skill.skill_id}: exists — skipped`);
        skippedCount++;
      } else if (skill.source === "generate" || skill.source === "fork") {
        scaffoldPackage(skill, repoRoot);
        newCount++;
      }
    }

    // Warn about skills in camp but not in domain-spec
    const removedSkills = oldSkills.filter(
      (id) => !specSkills.some((s) => s.skill_id === id)
    );
    for (const id of removedSkills) {
      log.warn(`  ${id}: in camp but not in domain-spec — remove manually if unneeded`);
    }

    // Step 5: Write manifest
    log.step(5, TOTAL_STEPS, "Writing manifest...");
    writeManifest(ctx);

    // Summary
    log.success(`Sync complete: ${skippedCount} skills preserved, ${newCount} new, ${removedSkills.length} orphaned`);
    console.log(`\n  Validate: campforge validate ${campDir}\n`);
  });
