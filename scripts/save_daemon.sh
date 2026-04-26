#!/usr/bin/env bash
set -uo pipefail

sleep_pid=""

cleanup() {
    tmux if -F "#{==:#{@_continuum_pid},$$}" "set-option -gqu @_continuum_pid" 2>/dev/null || true
}

terminate() {
    [[ -n "$sleep_pid" ]] && kill "$sleep_pid" 2>/dev/null || true
    cleanup
    exit 0
}

claim_or_exit() {
    local current_pid
    current_pid="$(tmux show-option -gqv @_continuum_pid 2>/dev/null || true)"

    if [[ -z "$current_pid" ]]; then
        tmux set-option -gq @_continuum_pid "$$"
        return 0
    fi

    [[ "$current_pid" == "$$" ]] || exit 0
}

sleep_for() {
    sleep "$1" &
    sleep_pid="$!"
    wait "$sleep_pid" 2>/dev/null
    sleep_pid=""
}

get_interval() {
    local interval
    interval="$(tmux show-option -gqv @continuum-save-interval 2>/dev/null)"
    if [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo "$interval"
    else
        echo 15
    fi
}

sleep_until_save_due() {
    local elapsed=0 interval total step

    while true; do
        interval="$(get_interval)"
        [[ "$interval" -eq 0 ]] && return 1

        total="$((interval * 60))"
        [[ "$elapsed" -ge "$total" ]] && return 0

        step="$((total - elapsed))"
        [[ "$step" -gt 60 ]] && step=60

        sleep_for "$step"
        elapsed="$((elapsed + step))"
        claim_or_exit
    done
}

trap cleanup EXIT
trap terminate TERM INT HUP

tmux set-option -gq @_continuum_pid "$$"

while true; do
    interval="$(get_interval)"

    if [[ "$interval" -eq 0 ]]; then
        sleep_for 60
        claim_or_exit
        continue
    fi

    sleep_until_save_due || continue

    save_script="$(tmux show-option -gqv @_continuum_save_script 2>/dev/null)"
    if [[ -z "$save_script" ]]; then
        tmux display-message "continuum: ERROR - tmux-resurrect save script path is unset. Reload tmux config." 2>/dev/null || true
    elif [[ ! -f "$save_script" ]]; then
        tmux display-message "continuum: ERROR - tmux-resurrect save script does not exist: $save_script" 2>/dev/null || true
    elif [[ ! -x "$save_script" ]]; then
        tmux display-message "continuum: ERROR - tmux-resurrect save script is not executable: $save_script" 2>/dev/null || true
    else
        "$save_script" quiet &>/dev/null &
        tmux set-option -gq @continuum-last-save "$(date +%s)"
    fi
done
