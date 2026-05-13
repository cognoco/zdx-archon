---
name: Archon daemon management
description: How to restart the Archon daemon, where the binary lives, and the launchd service name
type: reference
---

- **Service name:** `system/com.archon.server`
- **Restart:** `sudo launchctl kickstart -k system/com.archon.server`
- **Binary:** `/Users/vetinari/.local/bin/archon` → symlink to `/Users/vetinari/_dev/Archon/dist/binaries/archon-darwin-arm64`
- **Build:** `bun run build:binaries` from the Archon repo root
- **Logs:** `~/.archon/logs/archon.stdout.log`
- **Daemon is long-lived** — `process.env` is set once at startup, not per-workflow
