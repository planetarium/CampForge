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

## Windows-specific notes

- Use **Git Bash**, **MSYS2**, or **WSL** to run the install script and CLI
  wrappers. The installer generates both `.cmd` (for cmd.exe/PowerShell) and
  extensionless shell wrappers (for Git Bash).
- **Node 24+** may be required on Windows due to ESM module resolution issues
  in older Node versions. If you encounter `ERR_MODULE_NOT_FOUND` or similar
  errors, upgrade Node.
- Make sure the `.local/bin` directory created by the installer is on your
  PATH. The installer adds it automatically for the current session, but you
  may need to add it to your shell profile for persistence.
