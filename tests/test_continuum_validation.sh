#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/test_helpers.sh
source "$CURRENT_DIR/helpers/test_helpers.sh"

trap teardown_test_env EXIT

run_continuum_allow_failure() {
    tmux run-shell "$(test_shell_quote "$TEST_ROOT_DIR/continuum.tmux")" >/dev/null 2>&1 || true
}

tmux_option() {
    tmux show-option -gqv "$1" 2>/dev/null || true
}

tmux_messages() {
    tmux show-messages 2>/dev/null || true
}

test_missing_save_script_prevents_startup_and_restore_decision() {
    setup_test_env
    install_fake_resurrect_scripts
    rm -f "$TEST_FAKE_SAVE_SCRIPT"
    start_tmux_server
    configure_continuum 0 on

    run_continuum_allow_failure

    assert_eq "" "$(continuum_pid)" "daemon should not start with missing save script"
    assert_eq "" "$(tmux_option @_continuum_save_script)" "invalid save script should not be cached"
    assert_eq "" "$(tmux_option @_continuum_restore_script)" "restore script should not be cached after validation failure"
    assert_eq "" "$(tmux_option @_continuum_restored)" "restore decision should not be marked after validation failure"
    assert_file_missing "$TEST_RESTORE_LOG"
    assert_contains "tmux-resurrect save script does not exist" "$(tmux_messages)" "validation error should be reported"
}

test_non_executable_restore_script_prevents_startup_and_restore_decision() {
    setup_test_env
    install_fake_resurrect_scripts
    chmod -x "$TEST_FAKE_RESTORE_SCRIPT"
    start_tmux_server
    configure_continuum 0 on

    run_continuum_allow_failure

    assert_eq "" "$(continuum_pid)" "daemon should not start with non-executable restore script"
    assert_eq "" "$(tmux_option @_continuum_save_script)" "save script should not be cached after validation failure"
    assert_eq "" "$(tmux_option @_continuum_restore_script)" "invalid restore script should not be cached"
    assert_eq "" "$(tmux_option @_continuum_restored)" "restore decision should not be marked after validation failure"
    assert_file_missing "$TEST_RESTORE_LOG"
    assert_contains "tmux-resurrect restore script is not executable" "$(tmux_messages)" "validation error should be reported"
}

test_invalid_reload_stops_existing_daemon_and_clears_cached_paths() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    configure_continuum 0 off

    run_continuum
    local pid
    pid="$(continuum_pid)"
    assert_nonempty "$pid" "daemon pid should be set before invalid reload"
    assert_process_alive "$pid"

    rm -f "$TEST_FAKE_RESTORE_SCRIPT"
    run_continuum_allow_failure

    wait_for "old daemon to exit after invalid reload" process_dead "$pid"
    assert_eq "" "$(continuum_pid)" "daemon pid should be cleared after invalid reload"
    assert_eq "" "$(tmux_option @_continuum_save_script)" "cached save script should be cleared after invalid reload"
    assert_eq "" "$(tmux_option @_continuum_restore_script)" "cached restore script should be cleared after invalid reload"
    assert_contains "tmux-resurrect restore script does not exist" "$(tmux_messages)" "validation error should be reported"
}

main() {
    test_missing_save_script_prevents_startup_and_restore_decision
    test_non_executable_restore_script_prevents_startup_and_restore_decision
    test_invalid_reload_stops_existing_daemon_and_clears_cached_paths
}

main "$@"
