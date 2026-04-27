---
name: a2x
description: >
  Interact with A2A (Agent2Agent) protocol agents via the a2x CLI.
  Handles installation, agent card inspection, OAuth2 device-flow and
  SIWE bearer authentication, and blocking / streaming message exchange.
  Use when asked to talk to an A2A agent, send a message to an A2A
  endpoint, authenticate with an A2A service, or inspect an A2A agent card.
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires gh CLI to download release binaries. On macOS, requires `xattr` and `codesign` (both ship with the OS) to bypass Gatekeeper SIGKILL of unsigned binaries.
---

# a2x CLI Skill

`a2x` is the planetarium A2A protocol client. Releases are distributed as
single-file binaries from GitHub: https://github.com/planetarium/a2x/releases
(tagged `cli-v<version>`).

## Installation

### 1. Check if already installed

```bash
a2x --version 2>&1
```

If this prints a version, skip to "Inspecting an agent card". Otherwise install
following the steps below.

### 2. Resolve the latest CLI release tag

```bash
TAG=$(gh release list --repo planetarium/a2x --limit 30 \
  --json tagName --jq '.[].tagName | select(startswith("cli-v"))' | head -1)
echo "$TAG"
```

### 3. Pick the asset for the current platform

| OS / arch              | Asset name           |
|------------------------|----------------------|
| macOS / arm64          | `a2x-macos-arm64`    |
| macOS / x86_64         | `a2x-macos-x64`      |
| Linux / aarch64        | `a2x-linux-arm64`    |
| Linux / x86_64         | `a2x-linux-x64`      |
| Windows / x86_64       | `a2x-win-x64.exe`    |

```bash
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)   ASSET=a2x-macos-arm64 ;;
  Darwin/x86_64)  ASSET=a2x-macos-x64 ;;
  Linux/aarch64)  ASSET=a2x-linux-arm64 ;;
  Linux/x86_64)   ASSET=a2x-linux-x64 ;;
  *) echo "unsupported platform"; exit 1 ;;
esac
echo "$ASSET"
```

### 4. Download to `~/.local/bin/a2x`

```bash
mkdir -p ~/.local/bin
gh release download "$TAG" --repo planetarium/a2x \
  --pattern "$ASSET" --output ~/.local/bin/a2x --clobber
chmod +x ~/.local/bin/a2x
```

Make sure `~/.local/bin` is on `PATH`.

### 5. macOS only — bypass Gatekeeper SIGKILL

The downloaded binary is unsigned, so macOS terminates it with SIGKILL
(exit code `137`) on first run. Strip the quarantine attribute and ad-hoc
sign it:

```bash
xattr -c ~/.local/bin/a2x
codesign --force --sign - ~/.local/bin/a2x
```

`codesign --sign -` performs ad-hoc signing (no developer certificate
required). The binary still runs unsigned in terms of trust, but Gatekeeper
no longer kills it.

### 6. Verify

```bash
a2x --version
```

If this prints `0.x.y`, the install is good. If it exits with `137` again
on macOS, re-run step 5.

## Inspecting an agent card

Always run this first when working with an unfamiliar A2A endpoint — it
reveals which authentication schemes the agent requires and whether x402
payments are needed.

```bash
a2x a2a agent-card <agent-base-url>
```

For the raw JSON (useful when parsing security schemes programmatically):

```bash
curl -s <agent-base-url>/.well-known/agent-card.json | jq .
```

Key fields to inspect:

- `securitySchemes` — `bearerAuth` (SIWE), `deviceFlow` (OAuth2), or both
- `capabilities.extensions` — look for the x402 payments extension URI
  `https://github.com/google-agentic-commerce/a2a-x402/blob/main/spec/v0.2`
- `url` — the JSON-RPC endpoint (often `<base>/api/a2a`)

## Authentication

`a2x a2a send` and `a2x a2a stream` automatically prompt for an auth
method on the first call to a new agent. Tokens are cached in
`~/.a2x/tokens.json` keyed by agent base URL, so subsequent calls are
non-interactive until the token expires.

### OAuth2 Device Flow

Choose this when the user has no local wallet, or when the agent supports
it as a non-Ethereum-tied identity.

The CLI prints a URL with an embedded `user_code`:

```
To authenticate, visit:
https://<agent>/auth/device?user_code=XXXX-YYYY
```

**The agent cannot open the browser.** Ask the user to visit the URL and
approve. The CLI continues polling and completes the request once
authorization is granted.

Tip: when running inside a non-TTY environment (e.g. an automation
harness), run the CLI under a pty (`script -q /tmp/a2x.log <cmd>`) and
read the device URL from the log file before the user approves.

### SIWE Bearer (Sign-In with Ethereum)

Choose this when the user has a local wallet and the agent declares the
SIWE bearer extension. The CLI signs an EIP-4361 message with the active
wallet and uses the encoded token as `Authorization: Bearer …`.

Set up a wallet before first use:

```bash
a2x wallet create        # generate a new key
# or
a2x wallet create --import   # import an existing private key
a2x wallet show          # confirm active wallet
```

### Token cache

Tokens live in `~/.a2x/tokens.json`. Each entry is keyed by agent base
URL and contains `schemeClass` (`OAuth2DeviceCodeAuthScheme` or
`SiweBearerAuthScheme`) plus a `credential`. To force re-authentication,
delete the entry for that URL.

### Reusing the cached token for other endpoints

Many A2A services authenticate other HTTP endpoints (GraphQL, REST, AI
chat) with the same SIWE bearer token. The `credential` field in
`~/.a2x/tokens.json` is already a base64url-encoded `{message, signature}`
pair — usable as `Authorization: Bearer <credential>` directly, without
any further wrapping.

```bash
# Pull the cached token for a specific agent base URL
TOKEN=$(jq -r '."<agent-base-url>"[0].credential' ~/.a2x/tokens.json)

# Use it against another endpoint on the same service
curl -sS -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST <agent-base-url>/graphql \
  -d '{"query":"{ __schema { queryType { name } } }"}'
```

This works because the device-flow / SIWE entries store the same kind of
SIWE message → signature blob the server's other endpoints expect. Verify
this for any new agent by checking `llms.txt` or the agent card's
`securitySchemes`. If `bearerAuth.bearerFormat` is `SIWE` (or the agent
documents bearer auth at the same domain), the cached token is reusable.

`a2x` does not refresh the token automatically when used outside the
`a2x a2a *` commands. Re-run `a2x a2a send <url> "ping"` (or delete the
entry) once the cached token expires.

## Sending messages

### Blocking send

```bash
a2x a2a send <agent-base-url> "your message"
```

Useful flags:

- `--context-id <id>` — continue an existing conversation (re-use the
  `contextId` returned in a previous response)
- `-H "Key: Value"` — add a custom header
- `--json` — print the raw JSON-RPC response (useful for inspecting
  `history`, `parts`, and `status.state`)

### Streaming via SSE

```bash
a2x a2a stream <agent-base-url> "your message"
```

Same flags as `send`. The CLI prints each event as it arrives.

### Continuing a conversation

Capture `contextId` from the first response, then pass it to subsequent
calls:

```bash
CTX=$(a2x a2a send --json <url> "first turn" | jq -r '.contextId')
a2x a2a send --context-id "$CTX" <url> "second turn"
```

### Listing and managing tasks

```bash
a2x a2a task --help
```

Subcommands include `list`, `get <task-id>`, `cancel <task-id>`. Use
these when an agent returns a long-running task you want to inspect or
abort.

## x402 payments

If the agent card declares the x402 extension, `a2x a2a send` auto-signs
payment requirements up to `--max-amount` (default 10000 atomic units)
when the agent responds with `payment-required`. Inspect requirements
without paying:

```bash
a2x x402 --help
```

Disable auto-payment with `--no-x402`.

## Common pitfalls

- **macOS exit code 137**: the binary was killed by Gatekeeper. Re-run
  the `xattr -c` + `codesign --force --sign -` step from installation.
- **`gh release download` fails with auth error**: run `gh auth status`
  and authenticate if needed (`gh auth login`).
- **Device-flow URL never appears in piped output**: stdio buffering on
  pipes hides the prompt. Run under `script -q /tmp/a2x.log <cmd>` to
  force a pty so the URL is flushed.
- **Token expired**: delete the offending entry in `~/.a2x/tokens.json`
  (or the whole file) and re-run the command to trigger re-auth.
- **Agent card has only `deviceCode` flow declared**: older A2A clients
  may report "Unsupported OAuth flows". `a2x` supports device flow
  natively — make sure you are on a recent CLI release.
