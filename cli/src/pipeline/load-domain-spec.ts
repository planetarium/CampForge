import { readFileSync } from "node:fs";
import * as yaml from "js-yaml";
import { DomainSpecSchema, type DomainSpec } from "../schema/domain-spec.js";
import { log } from "../utils/logger.js";

export function loadDomainSpec(path: string): DomainSpec {
  const raw = readFileSync(path, "utf-8");
  const parsed = yaml.load(raw);
  const result = DomainSpecSchema.safeParse(parsed);

  if (!result.success) {
    log.error("Invalid domain spec:");
    for (const issue of result.error.issues) {
      log.error(`  ${issue.path.join(".")}: ${issue.message}`);
    }
    process.exit(1);
  }

  return result.data;
}
