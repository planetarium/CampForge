# CampForge

## Core Design Principles

### A camp is composition, not implementation

Camps contain no skill code. A camp declares identity (who the agent is), knowledge (what it knows), and which skills to compose — nothing more. All skills live in `packages/` as independent packages, referenced via `package.json` dependencies.

Why: Skills have their own dependency graphs (e.g. v8-api depends on gql-ops). The same skill can be shared across multiple camps. Embedding skills inside camps makes dependency management and recomposition impossible.

### skillpm resolves dependencies; install.sh drives installation

Skills are resolved through [skillpm](https://skillpm.dev/), which operates on top of npm's dependency resolution so transitive skill dependencies are handled automatically. Each camp has a single `install.sh` that sets up `package.json` with tarball URLs, runs `npx skillpm install`, and handles any camp-specific post-install steps (e.g. gws binary installation). Common post-install logic lives in `scripts/install-common.sh`.

### npm workspaces for local dev, GitHub Release tarballs for distribution

- **Local**: The root `package.json` workspaces link `packages/*` and `camps/*`. A single `npm install` connects everything.
- **Distribution**: `scripts/release-pack.sh` produces per-package tarballs attached to a GitHub Release. Nothing is published to the npm registry.
- **Remote install**: Each camp's `install.sh` constructs a `package.json` with tarball URLs, then runs `npx skillpm install`.

Why not npm publish: Some skills (v8-api, 9c-backoffice, iap-*) contain internal URLs and org-specific logic. Managing all packages the same way (tarballs) avoids split governance between "these go to npm, those don't."

### One install.sh per camp, shared logic in scripts/

Each camp has a single `install.sh` (the primary install path, designed for remote use via `curl | bash`). Camp-specific post-install dependencies (e.g. gws for v8-admin) source shared functions from `scripts/install-common.sh` — falling back to fetching it from GitHub raw URL when running outside a clone.

## Working in this repo

- To add a skill, create a new package in `packages/` and add it as a dependency in the camp's `package.json`. Do not create a `skills/` directory inside a camp.
- Tarball URLs in each camp's `install.sh` contain version numbers. When bumping a package version, update the corresponding filename in install.sh.
- Camp-specific post-install logic (e.g. gws install) should use shared functions from `scripts/install-common.sh`.
- `skillpm install` must run from the repo root in a workspace setup. Running it from a camp directory fails because npm hoists dependencies to the root `node_modules/`.
