import { join } from "node:path";
import { readFileSync } from "node:fs";
import { writeFile } from "../utils/fs.js";
import { chmodSync } from "node:fs";
import type { PipelineContext } from "../commands/create.js";
import { log } from "../utils/logger.js";

const SAFE_ID = /^[a-z0-9][a-z0-9-]*$/;

export function generateInstall(ctx: PipelineContext): void {
  const { domainSpec, outputDir } = ctx;
  const domainId = domainSpec.domain.id;

  if (!SAFE_ID.test(domainId)) {
    throw new Error(`Domain ID "${domainId}" contains unsafe characters. Use kebab-case (a-z, 0-9, hyphens).`);
  }

  // Read the package.json that resolveDeps already wrote
  const pkgJson = JSON.parse(
    readFileSync(join(outputDir, "package.json"), "utf-8")
  );
  const deps: Record<string, string> = pkgJson.dependencies || {};

  // Build npm pkg set lines — only @campforge/* deps get tarball URLs,
  // others are left as semver for npm registry resolution.
  const pkgSetLines = Object.keys(deps)
    .map((name) => {
      if (!name.startsWith("@campforge/")) {
        return `  "dependencies.${name}=${deps[name]}"`;
      }
      const bare = name.replace(/^@campforge\//, "");
      const version = deps[name].replace(/^[\^~>=<]*/, "");
      if (!version || version === "latest") {
        log.warn(`${name} has version "${deps[name]}" — tarball URL cannot be generated. Pin a version in package.json.`);
        return `  "dependencies.${name}=${deps[name]}"`;
      }
      const tarball = `campforge-${bare}-${version}.tgz`;
      return `  "dependencies.${name}=$BASE/${tarball}"`;
    })
    .join(" \\\n");

  const script = `#!/usr/bin/env bash
# Installer for ${domainId} camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/${domainId}/install.sh | bash
set -euo pipefail

CAMP_VERSION="\${CAMP_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/${domainId}-$CAMP_VERSION"

WS="\${WORKSPACE:-workspace}"
mkdir -p "$WS" && cd "$WS"

npm init -y --silent 2>/dev/null
npm pkg set \\
${pkgSetLines}

npx skillpm install

echo "${domainId} camp installed"
`;

  const path = join(outputDir, "install.sh");
  writeFile(path, script);
  chmodSync(path, 0o755);
}
