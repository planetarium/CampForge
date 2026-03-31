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

    // 2. Required directories (skills/ no longer required — skills come from packages)
    for (const d of ["identity", "adapters", "tests"]) {
      check(`${d}/ directory exists`, () => exists(join(abs, d)));
    }

    // 3. Identity files
    for (const f of ["SOUL.md", "IDENTITY.md", "AGENTS.md"]) {
      check(`identity/${f} exists`, () => exists(join(abs, "identity", f)));
    }

    // 4. Skills declared in package.json
    if (manifest) {
      const required: string[] = manifest.camp.skills.required;
      const pkgJsonPath = join(abs, "package.json");

      if (exists(pkgJsonPath)) {
        const pkgJson = JSON.parse(readFileSync(pkgJsonPath, "utf-8"));
        const deps = Object.keys(pkgJson.dependencies || {});

        for (const skill of required) {
          // skill can be "@campforge/v8-admin" (scoped) or "v8-admin" (bare)
          const scopedName = skill.startsWith("@") ? skill : `@campforge/${skill}`;
          check(`${scopedName} declared in package.json`, () =>
            deps.includes(scopedName)
          );
        }
      } else {
        check("package.json exists (skills are declared as dependencies)", () => false);
      }
    }

    // 5. At least one adapter with install.sh
    check("At least one adapter with install.sh", () => {
      for (const adapter of ["claude-code", "openclaw", "codex", "gemini-cli", "generic"]) {
        if (exists(join(abs, "adapters", adapter, "install.sh"))) return true;
      }
      return false;
    });

    // 6. campforge-cli.sh
    check("campforge-cli.sh exists", () => exists(join(abs, "campforge-cli.sh")));

    // Summary
    console.log(`\n${passed} passed, ${failed} failed\n`);
    if (failed > 0) process.exit(1);
  });
