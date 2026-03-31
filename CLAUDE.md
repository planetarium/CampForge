# CampForge

## Core Design Principles

### A camp is composition, not implementation

Camps contain no skill code. A camp declares identity (who the agent is), knowledge (what it knows), and which skills to compose — nothing more. All skills live in `packages/` as independent packages, referenced via `package.json` dependencies.

Why: Skills have their own dependency graphs (e.g. v8-admin depends on gql-ops). The same skill can be shared across multiple camps. Embedding skills inside camps makes dependency management and recomposition impossible.

### skillpm is the single skill installation path

Skills are always installed through [skillpm](https://skillpm.dev/). Adapter install scripts never copy files directly or hardcode paths. skillpm operates on top of npm's dependency resolution, so transitive skill dependencies are resolved automatically.

### npm workspaces for local dev, GitHub Release tarballs for distribution

- **Local**: The root `package.json` workspaces link `packages/*` and `camps/*`. A single `npm install` connects everything.
- **Distribution**: `scripts/release-pack.sh` produces per-package tarballs attached to a GitHub Release. Nothing is published to the npm registry.
- **Remote install**: `install-remote.sh` constructs a `package.json` with tarball URLs, then runs `npx skillpm install`.

Why not npm publish: Some skills (v8-admin, 9c-backoffice, iap-*) contain internal URLs and org-specific logic. Managing all packages the same way (tarballs) avoids split governance between "these go to npm, those don't."

### Adapters handle camp-specific context only

An adapter install script does exactly three things:
1. Run `npx skillpm install` from the repo root (resolves skills)
2. Copy only the skills declared in the camp's `package.json` to the target (grep filter)
3. Place identity and knowledge files according to the platform

Skill names are never hardcoded in adapters. `package.json` is the single source of truth.

## Working in this repo

- To add a skill, create a new package in `packages/` and add it as a dependency in the camp's `package.json`. Do not create a `skills/` directory inside a camp.
- When editing adapter install scripts, do not write skill names directly. Use the `node_modules/@campforge/*/skills/*/` glob filtered by `package.json` grep.
- Tarball URLs in `install-remote.sh` contain version numbers. When bumping a package version, update the corresponding filename in install-remote.sh.
- `skillpm install` must run from the repo root in a workspace setup. Running it from a camp directory fails because npm hoists dependencies to the root `node_modules/`.
