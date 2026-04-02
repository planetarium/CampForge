import { join } from "node:path";
import { readFileSync } from "node:fs";
import { writeFile } from "../utils/fs.js";
import { chmodSync } from "node:fs";
import type { PipelineContext } from "../commands/create.js";

export function generateInstall(ctx: PipelineContext): void {
  const { domainSpec, outputDir } = ctx;
  const domainId = domainSpec.domain.id;

  // Read the package.json that resolveDeps already wrote
  const pkgJson = JSON.parse(
    readFileSync(join(outputDir, "package.json"), "utf-8")
  );
  const deps: Record<string, string> = pkgJson.dependencies || {};

  // Build npm pkg set lines from dependencies
  const pkgSetLines = Object.keys(deps)
    .map((name) => {
      // @campforge/foo-bar ^1.0.0 → campforge-foo-bar-1.0.0.tgz
      const bare = name.replace(/^@campforge\//, "");
      const version = deps[name].replace(/^[\^~>=<]*/, "") || "1.0.0";
      const tarball = `campforge-${bare}-${version}.tgz`;
      return `  "dependencies.${name}=$BASE/${tarball}"`;
    })
    .join(" \\\n");

  const script = `#!/usr/bin/env bash
# Installer for ${domainId} camp
# Usage: curl -fsSL https://raw.githubusercontent.com/planetarium/CampForge/main/camps/${domainId}/install.sh | bash
set -euo pipefail

VERSION="\${CAMPFORGE_VERSION:-v1.0.0}"
BASE="https://github.com/planetarium/CampForge/releases/download/$VERSION"

WS="\${WORKSPACE:-.}"
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
