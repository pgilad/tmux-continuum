#!/usr/bin/env bash
set -uo pipefail

cleanup() {
    tmux set-option -gqu @_continuum_pid 2>/dev/null || true
}
trap cleanup EXIT TERM INT HUP

tmux set-option -gq @_continuum_pid "$$"

while true; do
    interval="$(tmux show-option -gqv @continuum-save-interval 2>/dev/null)"
    [[ ! "$interval" =~ ^[0-9]+$ ]] && interval=15

    if [[ "$interval" -eq 0 ]]; then
        sleep 60
        continue
    fi

    sleep "$((interval * 60))"

    # If another daemon has taken over, exit cleanly
    current_pid="$(tmux show-option -gqv @_continuum_pid 2>/dev/null)"
    [[ "$$" != "$current_pid" ]] && exit 0

    save_script="$(tmux show-option -gqv @_continuum_save_script 2>/dev/null)"
    if [[ -n "$save_script" && -x "$save_script" ]]; then
        "$save_script" quiet &>/dev/null &
        tmux set-option -gq @continuum-last-save "$(date +%s)"
    fi
done
