#!/usr/bin/env bash
set -euo pipefail

UNIT_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tmux.service"

generate_unit() {
    local tmux_path
    tmux_path="$(command -v tmux)"
    cat <<EOF
[Unit]
Description=tmux default session (detached)

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${tmux_path} new-session -d

[Install]
WantedBy=default.target
EOF
}

enable() {
    mkdir -p "$(dirname "$UNIT_PATH")"
    local content
    content="$(generate_unit)"
    if ! diff <(echo "$content") "$UNIT_PATH" &>/dev/null 2>&1; then
        echo "$content" > "$UNIT_PATH"
        systemctl --user daemon-reload
        systemctl --user enable tmux.service
        tmux display-message "continuum: systemd unit installed at $UNIT_PATH"
    else
        tmux display-message "continuum: systemd unit already up to date"
    fi
}

disable() {
    if [[ -f "$UNIT_PATH" ]]; then
        systemctl --user disable tmux.service 2>/dev/null || true
        rm -f "$UNIT_PATH"
        systemctl --user daemon-reload
        tmux display-message "continuum: systemd unit removed"
    else
        tmux display-message "continuum: no systemd unit found"
    fi
}

"${1:?Usage: systemd.sh enable|disable}"
