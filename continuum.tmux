#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$CURRENT_DIR/scripts"
RESTORE_FRESH_MAX_AGE_SECONDS=30

# --- Inline helpers ---

get_option()  { tmux show-option -gqv "$1"; }
set_option()  { tmux set-option -gq "$1" "$2"; }

# --- Resurrect path resolution ---

resolve_resurrect_script() {
    local option="$1" fallback="$2"
    local path
    path="$(get_option "$option")"
    if [[ -z "$path" ]]; then
        # Standard tpm sibling layout
        local candidate="$CURRENT_DIR/../tmux-resurrect/scripts/$fallback"
        [[ -f "$candidate" ]] && path="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    fi
    if [[ -z "$path" ]]; then
        # tpm-rs namespaced layout
        local candidate="$CURRENT_DIR/../tmux-plugins/tmux-resurrect/scripts/$fallback"
        [[ -f "$candidate" ]] && path="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    fi
    echo "$path"
}

validate_resurrect() {
    local save_script restore_script
    save_script="$(resolve_resurrect_script "@resurrect-save-script-path" "save.sh")"
    restore_script="$(resolve_resurrect_script "@resurrect-restore-script-path" "restore.sh")"

    if [[ -z "$save_script" || -z "$restore_script" ]]; then
        tmux display-message "continuum: ERROR - tmux-resurrect not found. Install it and reload."
        return 1
    fi

    set_option "@_continuum_save_script" "$save_script"
    set_option "@_continuum_restore_script" "$restore_script"
}

# --- Save daemon lifecycle ---

start_save_daemon() {
    local old_pid
    old_pid="$(get_option "@_continuum_pid")"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
        sleep 0.2
    fi

    tmux run-shell -b "$SCRIPTS/save_daemon.sh"
}

# --- Auto-restore ---

count_tmux_items() {
    tmux "$@" 2>/dev/null | awk 'END { print NR + 0 }'
}

recent_server_start() {
    local start_time now
    start_time="$(tmux display-message -p -F '#{start_time}' 2>/dev/null)"
    [[ "$start_time" =~ ^[0-9]+$ ]] || return 1

    now="$(date +%s)"
    [[ "$now" =~ ^[0-9]+$ ]] || return 1

    (( now >= start_time && now - start_time <= RESTORE_FRESH_MAX_AGE_SECONDS ))
}

default_server_shape() {
    local sessions windows panes
    sessions="$(count_tmux_items list-sessions -F '#{session_id}')"
    windows="$(count_tmux_items list-windows -a -F '#{window_id}')"
    panes="$(count_tmux_items list-panes -a -F '#{pane_id}')"

    [[ "$sessions" -eq 1 && "$windows" -eq 1 && "$panes" -eq 1 ]]
}

fresh_server_for_restore() {
    recent_server_start && default_server_shape
}

maybe_restore() {
    local already
    already="$(get_option "@_continuum_restored")"
    [[ -n "$already" ]] && return 0

    local enabled
    enabled="$(get_option "@continuum-restore")"
    if [[ "$enabled" == "on" ]] && fresh_server_for_restore; then
        tmux run-shell -b "$SCRIPTS/restore.sh"
    fi

    # Set flag regardless — we've made the restore decision for this server lifetime
    set_option "@_continuum_restored" 1
}

# --- Boot command aliases ---

register_boot_commands() {
    # shellcheck disable=SC2102  # [N] is tmux array index syntax, not a char range
    tmux set-option -s command-alias[200] \
        continuum-boot-enable="run-shell -b '$SCRIPTS/boot/setup.sh enable'"
    # shellcheck disable=SC2102
    tmux set-option -s command-alias[201] \
        continuum-boot-disable="run-shell -b '$SCRIPTS/boot/setup.sh disable'"
}

# --- Status interpolation ---

update_status_interpolation() {
    local option="$1"
    local value
    value="$(get_option "$option")"
    if [[ "$value" == *'#{continuum_status}'* ]]; then
        local replacement="#($SCRIPTS/status.sh)"
        set_option "$option" "${value//'#{continuum_status}'/$replacement}"
    fi
}

# --- Main ---

main() {
    validate_resurrect || return
    start_save_daemon
    maybe_restore
    register_boot_commands
    update_status_interpolation "status-right"
    update_status_interpolation "status-left"
}
main
