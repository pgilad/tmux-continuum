#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$CURRENT_DIR/scripts"

# --- Inline helpers ---

get_option()  { tmux show-option -gqv "$1"; }
set_option()  { tmux set-option -gq "$1" "$2"; }

get_interval() {
    local val
    val="$(get_option "@continuum-save-interval")"
    if [[ "$val" =~ ^[0-9]+$ ]]; then echo "$val"; else echo 15; fi
}

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
    local interval
    interval="$(get_interval)"
    [[ "$interval" -eq 0 ]] && return 0

    local old_pid
    old_pid="$(get_option "@_continuum_pid")"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
        sleep 0.2
    fi

    tmux run-shell -b "$SCRIPTS/save_daemon.sh"
}

# --- Auto-restore ---

maybe_restore() {
    local already
    already="$(get_option "@_continuum_restored")"
    [[ -n "$already" ]] && return 0

    local enabled
    enabled="$(get_option "@continuum-restore")"
    [[ "$enabled" == "on" ]] && tmux run-shell -b "$SCRIPTS/restore.sh"

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
