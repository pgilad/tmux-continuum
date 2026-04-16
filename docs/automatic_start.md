# Automatic tmux start

Tmux can be started automatically when the computer boots or the user logs in.

Unlike previous versions of this plugin, automatic start is **not** configured
via `.tmux.conf` options. Instead, you run an explicit tmux command to install
(or remove) the system-level configuration.

### Enabling

From inside tmux, run:

    :continuum-boot-enable

This installs a platform-appropriate service:
- **macOS**: a LaunchAgent at `~/Library/LaunchAgents/com.tmux.server.plist`
- **Linux**: a systemd user unit at `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tmux.service`

The service runs `tmux new-session -d` on login, which starts a headless tmux
server. It does **not** open any terminal window.

To attach to the server when you open a terminal, add this to your
`.bashrc`/`.zshrc`:

```sh
[[ -z "$TMUX" ]] && tmux attach 2>/dev/null
```

### Disabling

From inside tmux, run:

    :continuum-boot-disable

This removes the LaunchAgent or systemd unit.

### Design notes

The LaunchAgent/systemd unit does **not** reference the plugin directory. It is a
standalone service that starts tmux. This means:

- It continues to work even if the plugin is uninstalled.
- No terminal emulator selection or AppleScript is involved.
- No accessibility permissions are required on macOS.
- You may choose to keep it after removing tmux-continuum.

### Migrating from `@continuum-boot`

If you previously used `set -g @continuum-boot 'on'`:

1. Remove the option (and `@continuum-boot-options`) from `.tmux.conf`.
2. Run `:continuum-boot-enable` inside tmux.
3. Remove the old macOS plist: `rm ~/Library/LaunchAgents/Tmux.Start.plist`
