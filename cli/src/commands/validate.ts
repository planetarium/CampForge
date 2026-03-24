import { Command } from "commander";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import * as yaml from "js-yaml";
import { ManifestSchema } from "../schema/manifest.js";
import { exists } from "../utils/fs.js";
import { log } from "../utils/logger.js";

export const validateCommand = new Command("validate")
  .description("Validate a camp directory")
  .argument("<dir>", "Camp directory to validate")
  .action((dir: string) => {
    const abs = resolve(dir);
    let passed = 0;
    let failed = 0;

    function check(name: string, fn: () => boolean) {
      try {
        if (fn()) {
          log.pass(name);
          passed++;
        } else {
          log.fail(name);
          failed++;
        }
      } catch (e) {
        log.fail(`${name} — ${e instanceof Error ? e.message : e}`);
        failed++;
      }
    }

    console.log(`\nValidating: ${abs}\n`);

    // 1. manifest.yaml exists and parses
    let manifest: any = null;
    check("manifest.yaml exists and is valid", () => {
      const raw = readFileSync(join(abs, "manifest.yaml"), "utf-8");
      const parsed = yaml.load(raw);
      const result = ManifestSchema.safeParse(parsed);
      if (!result.success) {
        const issues = result.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`);
        throw new Error(issues.join("; "));
      }
      manifest = result.data;
      return true;
    });

    // 2. Required directories
    for (const d of ["identity", "skills", "adapters", "tests"]) {
      check(`${d}/ directory exists`, () => exists(join(abs, d)));
    }

    // 3. Identity files
    for (const f of ["SOUL.md", "IDENTITY.md", "AGENTS.md"]) {
      check(`identity/${f} exists`, () => exists(join(abs, "identity", f)));
    }

    // 4. Skills match manifest
    if (manifest) {
      const required: string[] = manifest.camp.skills.required;
      for (const skill of required) {
        check(`skills/${skill}/SKILL.md exists`, () =>
          exists(join(abs, "skills", skill, "SKILL.md"))
        );
      }

      // 5. SKILL.md frontmatter validation
      for (const skill of required) {
        check(`skills/${skill}/SKILL.md has valid frontmatter`, () => {
          const content = readFileSync(join(abs, "skills", skill, "SKILL.md"), "utf-8");
          const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
          if (!fmMatch) return false;
          const fm = yaml.load(fmMatch[1]) as any;
          return typeof fm.name === "string" && typeof fm.description === "string";
        });
      }
    }

    // 6. At least one adapter with install.sh
    check("At least one adapter with install.sh", () => {
      for (const adapter of ["claude-code", "openclaw", "codex", "gemini-cli", "generic"]) {
        if (exists(join(abs, "adapters", adapter, "install.sh"))) return true;
      }
      return false;
    });

    // 7. package.json if skill deps exist
    if (manifest?.camp.dependencies?.skills?.length) {
      check("package.json exists (skill dependencies declared)", () =>
        exists(join(abs, "package.json"))
      );
    }

    // 8. campforge-cli.sh
    check("campforge-cli.sh exists", () => exists(join(abs, "campforge-cli.sh")));

    // Summary
    console.log(`\n${passed} passed, ${failed} failed\n`);
    if (failed > 0) process.exit(1);
  });
