import { dirname, join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

/**
 * Walk up from startDir until we find a package.json with "workspaces"
 * containing "packages/*" — that's the CampForge repo root.
 */
export function findRepoRoot(startDir: string): string {
  let dir = startDir;
  while (dir !== dirname(dir)) {
    const pkgPath = join(dir, "package.json");
    if (existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
        if (
          Array.isArray(pkg.workspaces) &&
          pkg.workspaces.includes("packages/*")
        ) {
          return dir;
        }
      } catch {
        // invalid JSON, keep walking
      }
    }
    dir = dirname(dir);
  }
  throw new Error(
    `Could not find CampForge repo root (no package.json with "packages/*" workspace found above ${startDir})`
  );
}
