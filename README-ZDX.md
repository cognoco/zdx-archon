# ZDX Archon — Cognoco Fork

Fork of [coleam00/archon](https://github.com/coleam00/archon) with ZDX-specific customizations.

**Fork repo:** [cognoco/zdx-archon](https://github.com/cognoco/zdx-archon)

## Git Setup

Remotes:

- `origin` — `cognoco/zdx-archon` (our fork, push here)
- `upstream` — `coleam00/archon` (original repo, pull updates from here)

Branches:

- `dev` — tracks `upstream/dev`, kept clean for syncing
- `zdx/customizations` — our custom changes on top of upstream

## Syncing with Upstream

When the original repo has updates you want to pull in:

```bash
git checkout dev
git fetch upstream
git merge upstream/dev
git push origin dev

git checkout zdx/customizations
git merge dev
# Resolve any conflicts, then:
git push origin zdx/customizations
```

## ZDX Customizations

Changes on `zdx/customizations` that diverge from upstream:

- **Dark/light/system theme toggle** — CSS variable-based theming with a 3-way toggle (sun/moon/monitor) in the top-right nav bar. Persists to localStorage, respects OS `prefers-color-scheme` in system mode.

## Deploying Custom Web UI

After making frontend changes, rebuild and deploy to the daemon:

```bash
bun --filter @archon/web build
cp -r packages/web/dist/* ~/.archon/web-dist/<version>/
sudo launchctl kickstart -k system/com.archon.server
```

Hard-refresh the browser (`Cmd+Shift+R`) to clear cached assets.

## Archon Serve — Background Daemon (macOS)

`archon serve` runs as a system-level LaunchDaemon, starting automatically on boot and restarting on crash.

### Configuration

**Plist:** `/Library/LaunchDaemons/com.archon.server.plist`
**Binary:** `/Users/vetinari/.local/bin/archon serve`
**Logs:** `~/.archon/logs/archon.stdout.log` and `~/.archon/logs/archon.stderr.log`
**Env:** `~/.archon/.env` (Telegram, GitHub, Slack tokens etc.)
**Config:** `~/.archon/config.yaml` (assistant defaults, streaming modes)
**Port:** 3090 (default)

### Managing the daemon

All commands require `sudo` because it's a system-level daemon.

```bash
# Check status
sudo launchctl print system/com.archon.server

# Restart (stop + start)
sudo launchctl kickstart -k system/com.archon.server

# Stop temporarily (KeepAlive will restart it)
sudo launchctl kill SIGTERM system/com.archon.server

# Stop permanently (until next boot or manual load)
sudo launchctl bootout system/com.archon.server

# Load again after bootout
sudo launchctl bootstrap system /Library/LaunchDaemons/com.archon.server.plist
```

### Checking health

```bash
curl -s http://localhost:3090/api/health | python3 -m json.tool
```

### Viewing logs

```bash
# Follow live output
tail -f ~/.archon/logs/archon.stdout.log

# Check for errors
grep -i error ~/.archon/logs/archon.stderr.log
```

### Common issues

**Port conflict:** If you run `archon serve` manually while the daemon is active, one of them will fail to bind port 3090. Kill the manual one and let the daemon handle it.

**Telegram 409 errors:** Only one process can poll a Telegram bot token at a time. If you see `409: Conflict` in the logs, ensure no other machine or process is using the same `TELEGRAM_BOT_TOKEN`.

**Crash loop:** If the daemon keeps restarting (`runs` count climbing in `launchctl print`), check `~/.archon/logs/archon.stderr.log` for the root cause.

### Updating from upstream release

After installing a new `archon` binary at `~/.local/bin/archon`, restart the daemon:

```bash
sudo launchctl kickstart -k system/com.archon.server
```
