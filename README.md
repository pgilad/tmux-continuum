# tmux-continuum

Continuous saving and automatic restoring for [tmux](https://github.com/tmux/tmux).

- **Auto-save** — periodically saves your tmux environment in the background
- **Auto-restore** — restores the last saved environment when tmux starts
- **Auto-start** — optionally starts tmux on boot (macOS / Linux)

No matter the crash or restart, tmux will be there how you left it.

Works on Linux and macOS. Requires **tmux 3.2+** and **bash**.

## How it works

Continuum runs a single background daemon (via `tmux run-shell -b`) that
sleeps for the configured interval and then calls
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)'s save
script. No status-line hacks, no locks, no periodic forks.

On a fresh server start, continuum optionally triggers resurrect's restore
script exactly once, guarded by a server-scoped flag — re-sourcing your
config will never re-trigger a restore.

## Requirements

- `tmux 3.2` or higher
- `bash`
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)

**tmux-resurrect must load before tmux-continuum.** List it first in your
plugin manager config.

## Installation

### With [tpm-rs](https://github.com/pgilad/tpm-rs) (recommended)

[tpm-rs](https://github.com/pgilad/tpm-rs) is a modern, fast tmux plugin
manager written in Rust. Add to your `tpm.yaml`:

```yaml
plugins:
  - name: tmux-plugins/tmux-resurrect
  - name: tmux-plugins/tmux-continuum
```

Run `tpm install` and reload your config. Auto-save starts immediately.

### With [TPM](https://github.com/tmux-plugins/tpm) (legacy)

Add to `.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
```

Press `prefix + I` to install. The plugin starts working in the background
automatically.

### Manual

```sh
git clone https://github.com/tmux-plugins/tmux-continuum ~/path/to/continuum
```

Add to `.tmux.conf`:

```tmux
run-shell ~/path/to/continuum/continuum.tmux
```

Reload: `tmux source-file ~/.tmux.conf`

## Configuration

| Option | Default | Description |
|---|---|---|
| `@continuum-save-interval` | `15` | Auto-save interval in minutes. `0` to pause. |
| `@continuum-restore` | `off` | Set to `on` to restore on fresh server start. |

### Auto-save

Saves run every 15 minutes by default. Change the interval:

```tmux
set -g @continuum-save-interval '30'
```

Disable (pause) saving:

```tmux
set -g @continuum-save-interval '0'
```

Setting the interval to `0` pauses the daemon — it checks back every 60
seconds. Change the interval back to re-enable without re-sourcing your config.

### Auto-restore

```tmux
set -g @continuum-restore 'on'
```

Restore runs **once** per server lifetime, on the first plugin load after server
start. Re-sourcing `.tmux.conf` will not trigger it again.

To suppress restore without changing your config, create a halt file:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
touch "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/no-auto-restore"
```

Override the halt file path with the `TMUX_CONTINUUM_NO_RESTORE` env var.

### Auto-start on boot

Start a headless tmux server on login. From inside tmux:

```
:continuum-boot-enable
```

This installs a **macOS LaunchAgent** or **Linux systemd user unit** that runs
`tmux new-session -d`. The service is standalone — it does not reference the
plugin directory and keeps working even if the plugin is removed.

To attach automatically when you open a terminal, add to your shell rc:

```sh
[[ -z "$TMUX" ]] && tmux attach 2>/dev/null
```

To remove:

```
:continuum-boot-disable
```

See [docs/automatic_start.md](docs/automatic_start.md) for details.

### Status line

Add `#{continuum_status}` to `status-right` or `status-left`:

```tmux
set -g status-right 'Continuum: #{continuum_status}'
```

Shows:
- `3m ago` — time since last save
- `15m` — configured interval (before first save completes)
- `off` — saving is paused

See [docs/continuum_status.md](docs/continuum_status.md).

## Docs

- [FAQ](docs/faq.md)
- [Auto-start on boot](docs/automatic_start.md)
- [Status line interpolation](docs/continuum_status.md)

## Migrating from older versions

If upgrading from a version that used `@continuum-boot`:

1. Remove `@continuum-boot` and `@continuum-boot-options` from `.tmux.conf`.
2. Run `:continuum-boot-enable` inside tmux to install the new service.
3. Delete the old macOS plist if present:
   `rm ~/Library/LaunchAgents/Tmux.Start.plist`
4. Move the old halt file if used:
   `mv ~/tmux_no_auto_restore "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/no-auto-restore"`

Removed options (safe to delete from `.tmux.conf`):
- `@continuum-boot`, `@continuum-boot-options`
- `@continuum-restore-max-delay`
- `@continuum-systemd-start-cmd`
- `@continuum-status-on-wrap-style`, `@continuum-status-off-wrap-style`

## Contributing

Bug reports and contributions are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE.md)
