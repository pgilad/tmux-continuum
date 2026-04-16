#!/usr/bin/env bash
set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.tmux.server.plist"

generate_plist() {
    local tmux_path
    tmux_path="$(command -v tmux)"
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tmux.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>${tmux_path}</string>
        <string>new-session</string>
        <string>-d</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF
}

enable() {
    mkdir -p "$(dirname "$PLIST_PATH")"
    local content
    content="$(generate_plist)"
    if ! diff <(echo "$content") "$PLIST_PATH" &>/dev/null 2>&1; then
        echo "$content" > "$PLIST_PATH"
        tmux display-message "continuum: LaunchAgent installed at $PLIST_PATH"
    else
        tmux display-message "continuum: LaunchAgent already up to date"
    fi
}

disable() {
    if [[ -f "$PLIST_PATH" ]]; then
        rm -f "$PLIST_PATH"
        tmux display-message "continuum: LaunchAgent removed"
    else
        tmux display-message "continuum: no LaunchAgent found"
    fi
}

"${1:?Usage: launchd.sh enable|disable}"
