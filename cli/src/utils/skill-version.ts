import { join } from "node:path";
import { readFileSync } from "node:fs";
import { exists } from "./fs.js";

const DEFAULT_VERSION_RANGE = "^0.1.0";

/**
 * Read the version from packages/{skillId}/package.json and return a caret range.
 * Falls back to ^0.1.0 if the package doesn't exist or has no version.
 */
export function readSkillVersion(repoRoot: string, skillId: string): string {
  const pkgPath = join(repoRoot, "packages", skillId, "package.json");
  if (exists(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      if (typeof pkg.version === "string" && pkg.version.trim()) {
        return `^${pkg.version}`;
      }
    } catch {
      // invalid JSON, fall through
    }
  }
  return DEFAULT_VERSION_RANGE;
}
