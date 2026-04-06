import { dirname, join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

function walkUpForWorkspace(startDir: string): string | null {
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
  return null;
}

/**
 * Find the CampForge repo root by walking up from startDir,
 * falling back to process.cwd() if startDir is outside the repo.
 */
export function findRepoRoot(startDir: string): string {
  const result = walkUpForWorkspace(startDir) ?? walkUpForWorkspace(process.cwd());
  if (!result) {
    throw new Error(
      `Could not find CampForge repo root (no package.json with "packages/*" workspace found above ${startDir} or ${process.cwd()})`
    );
  }
  return result;
}
