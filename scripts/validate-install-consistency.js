#!/usr/bin/env node
// Validate internal consistency of camps/*/install.sh against package.json files.
//
// Catches: install.sh referencing tarball versions that don't match packages/*/package.json,
// or dep lists that diverge between install.sh and camps/<camp>/package.json.
// Does NOT check whether the referenced GitHub Release actually exists.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const CAMPS_DIR = path.join(REPO_ROOT, 'camps');
const PACKAGES_DIR = path.join(REPO_ROOT, 'packages');

const TARBALL_LINE = /dependencies\.@campforge\/([a-z0-9-]+)=\$BASE\/campforge-([a-z0-9-]+)-(\d+\.\d+\.\d+)\.tgz/g;
const CAMP_FILES_LINE = /install_camp_files\s+"\$BASE\/camp-([a-z0-9-]+)\.tgz"/;

const errors = [];

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function pkgVersion(name) {
  const p = path.join(PACKAGES_DIR, name, 'package.json');
  if (!fs.existsSync(p)) return null;
  return readJson(p).version;
}

function validateCamp(camp) {
  const campDir = path.join(CAMPS_DIR, camp);
  const installPath = path.join(campDir, 'install.sh');
  const pkgPath = path.join(campDir, 'package.json');
  const hasInstall = fs.existsSync(installPath);
  const hasPkg = fs.existsSync(pkgPath);
  if (!hasInstall && !hasPkg) return;
  if (!hasInstall) errors.push(`[${camp}] missing required file: camps/${camp}/install.sh`);
  if (!hasPkg) errors.push(`[${camp}] missing required file: camps/${camp}/package.json`);
  if (!hasInstall || !hasPkg) return;

  const install = fs.readFileSync(installPath, 'utf8');
  const campPkg = readJson(pkgPath);
  const campDeps = new Set(
    Object.keys(campPkg.dependencies || {})
      .filter((d) => d.startsWith('@campforge/'))
      .map((d) => d.slice('@campforge/'.length))
  );

  const installDeps = new Set();
  for (const m of install.matchAll(TARBALL_LINE)) {
    const [, depName, fileName, version] = m;
    installDeps.add(depName);

    if (depName !== fileName) {
      errors.push(`[${camp}] tarball name mismatch: @campforge/${depName} references campforge-${fileName}-${version}.tgz`);
      continue;
    }

    const actual = pkgVersion(depName);
    if (actual === null) {
      errors.push(`[${camp}] install.sh references @campforge/${depName} but packages/${depName}/ does not exist`);
    } else if (actual !== version) {
      errors.push(`[${camp}] @campforge/${depName}: install.sh pins ${version} but packages/${depName}/package.json is ${actual}`);
    }
  }

  for (const dep of campDeps) {
    if (!installDeps.has(dep)) {
      errors.push(`[${camp}] @campforge/${dep} is in camps/${camp}/package.json but not referenced in install.sh`);
    }
  }
  for (const dep of installDeps) {
    if (!campDeps.has(dep)) {
      errors.push(`[${camp}] @campforge/${dep} is referenced in install.sh but not in camps/${camp}/package.json dependencies`);
    }
  }

  const campTgzMatch = install.match(CAMP_FILES_LINE);
  if (campTgzMatch && campTgzMatch[1] !== camp) {
    errors.push(`[${camp}] install_camp_files uses camp-${campTgzMatch[1]}.tgz but camp directory is '${camp}'`);
  }
}

const camps = fs.readdirSync(CAMPS_DIR).filter((d) => {
  return fs.statSync(path.join(CAMPS_DIR, d)).isDirectory();
});

for (const camp of camps) {
  validateCamp(camp);
}

if (errors.length > 0) {
  console.error('install.sh consistency check FAILED:\n');
  for (const e of errors) console.error('  - ' + e);
  console.error(`\n${errors.length} issue(s). Update install.sh and/or package.json so they agree.`);
  process.exit(1);
}

console.log(`install.sh consistency check OK (${camps.length} camps)`);
