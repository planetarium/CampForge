# Playwriter Dependency Chain

flex-ax crawl uses [Playwriter](https://github.com/nicepkg/playwriter) to
interact with the flex.team web UI through a real browser session. All four
pieces below must be in place before `flex-ax crawl` can succeed.

## Prerequisites

1. **Chrome extension** -- Install the Playwriter Chrome extension from the
   Chrome Web Store.
2. **Logged-in flex.team tab** -- Open Chrome and sign in to your flex.team
   workspace. Keep at least one tab with flex.team loaded.
3. **Local Playwriter server** -- Start the relay server:
   ```bash
   npx -y playwriter@latest serve --host 127.0.0.1
   ```
   The server listens on `127.0.0.1:19988` by default.
4. **Relay reachable** -- flex-ax connects to the Playwriter relay at
   `127.0.0.1:19988`. Ensure no firewall or proxy blocks this port.

## Verifying the Relay

```bash
curl http://127.0.0.1:19988/json/version
```

A successful response returns JSON with Chrome version information, confirming the relay is active.

## Full Workflow

1. Start the relay: `playwriter serve --host 127.0.0.1`
2. Open Chrome and navigate to flex.team.
3. Log in to flex.team if not already logged in.
4. Activate the Playwriter Chrome extension on the flex.team tab.
5. Run the crawl: `flex-ax crawl --auth playwriter`

## Windows-specific notes

- Use **Git Bash** (or MSYS2 / WSL) as the default shell on Windows.
  All CLI commands and examples in this camp assume a bash-compatible shell.
- Make sure the `.local/bin` directory created by the installer is on your
  PATH. The installer adds it automatically for the current session, but you
  may need to add it to your shell profile for persistence.

> **Node 24+ is REQUIRED on Windows.** Playwriter is a pure ESM package. On Windows
> with Node versions older than 24, `playwriter serve` will fail with
> `ERR_REQUIRE_ESM` or `SyntaxError: Cannot use import statement outside a module`.
> This is an upstream Node/ESM interop limitation that cannot be worked around.
>
> Download Node 24+: <https://nodejs.org/>

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Waiting for MCP WS Server..." | Relay is not running | Start it with `playwriter serve --host 127.0.0.1` |
| Connection refused on port 19988 | Relay crashed or bound to a different host | Restart the relay; ensure `--host 127.0.0.1` is specified |
| ESM / import errors on Windows | Node version too old | Upgrade Node to 24+ |
