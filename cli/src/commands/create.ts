import { Command } from "commander";
import { resolve } from "node:path";
import { DomainSpecSchema } from "../schema/domain-spec.js";
import { log } from "../utils/logger.js";
import { loadDomainSpec } from "../pipeline/load-domain-spec.js";
import { generateIdentity } from "../pipeline/generate-identity.js";
import { generateSkills } from "../pipeline/generate-skills.js";
import { resolveDeps } from "../pipeline/resolve-deps.js";
import { packageKnowledge } from "../pipeline/package-knowledge.js";
import { generateAdapters } from "../pipeline/generate-adapters.js";
import { generateTests } from "../pipeline/generate-tests.js";
import { writeManifest } from "../pipeline/write-manifest.js";
import { initRepo } from "../pipeline/init-repo.js";

export interface PipelineContext {
  domainSpec: ReturnType<typeof DomainSpecSchema.parse>;
  persona: "junior" | "mid" | "senior" | "lead";
  language: string;
  outputDir: string;
  extras: string[];
  adapters: string[];
}

const TOTAL_STEPS = 8;

export const createCommand = new Command("create")
  .description("Create a new camp from a domain spec")
  .requiredOption("--from <path>", "Domain spec YAML file")
  .option("--persona <level>", "Persona level", "senior")
  .option("--language <lang>", "Language", "ko")
  .option("--output <dir>", "Output directory")
  .option("--extras <skills>", "Comma-separated elective skill IDs", "")
  .option("--adapters <list>", "Comma-separated adapters", "claude-code,openclaw,generic")
  .action((opts) => {
    const specPath = resolve(opts.from);
    const domainSpec = loadDomainSpec(specPath);
    const domainId = domainSpec.domain.id;
    const outputDir = resolve(opts.output || `campforge-${domainId}`);

    const ctx: PipelineContext = {
      domainSpec,
      persona: opts.persona,
      language: opts.language,
      outputDir,
      extras: opts.extras ? opts.extras.split(",").filter(Boolean) : [],
      adapters: opts.adapters.split(",").filter(Boolean),
    };

    console.log(`\n=== CampForge: Creating camp "${domainId}" ===\n`);

    log.step(1, TOTAL_STEPS, "Loading domain spec...");

    log.step(2, TOTAL_STEPS, "Generating identity files...");
    generateIdentity(ctx);

    log.step(3, TOTAL_STEPS, "Scaffolding skills...");
    generateSkills(ctx);

    log.step(4, TOTAL_STEPS, "Resolving skill dependencies...");
    resolveDeps(ctx);

    log.step(5, TOTAL_STEPS, "Packaging knowledge...");
    packageKnowledge(ctx);

    log.step(6, TOTAL_STEPS, "Generating platform adapters...");
    generateAdapters(ctx);

    log.step(7, TOTAL_STEPS, "Generating tests...");
    generateTests(ctx);

    log.step(8, TOTAL_STEPS, "Writing manifest & initializing repo...");
    writeManifest(ctx);
    initRepo(ctx);

    log.success(`Camp created at: ${outputDir}`);
    console.log(`\n  Next: have your LLM fill in the skill SKILL.md files`);
    console.log(`  Install: cd ${domainId} && ./campforge-cli.sh`);
    console.log(`  Validate: campforge validate ${outputDir}\n`);
  });
