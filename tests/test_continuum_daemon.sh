#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/test_helpers.sh
source "$CURRENT_DIR/helpers/test_helpers.sh"

trap teardown_test_env EXIT

test_daemon_restarts_cleanly_on_plugin_reload() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    configure_continuum 1 off

    run_continuum
    local pid1
    pid1="$(continuum_pid)"
    assert_nonempty "$pid1" "initial daemon pid should be set"
    assert_process_alive "$pid1"

    run_continuum
    local pid2
    pid2="$(continuum_pid)"
    assert_nonempty "$pid2" "reloaded daemon pid should be set"
    assert_process_alive "$pid2"
    [ "$pid1" != "$pid2" ] || fail "daemon pid should change after reload"

    wait_for "old daemon to exit" process_dead "$pid1"
    assert_eq "$pid2" "$(continuum_pid)" "new daemon should remain the current owner"
    assert_process_alive "$pid2"
}

test_daemon_starts_when_interval_is_initially_paused() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    configure_continuum 0 off

    run_continuum
    local pid
    pid="$(continuum_pid)"
    assert_nonempty "$pid" "paused daemon pid should be set"
    assert_process_alive "$pid"
}

test_daemon_does_not_save_after_interval_is_paused_during_wait() {
    setup_test_env
    install_fake_resurrect_scripts
    install_sleep_wrapper_that_pauses_interval
    start_tmux_server
    configure_continuum 1 off

    run_continuum
    /bin/sleep 0.3

    assert_eq "0" "$(tmux show-option -gqv @continuum-save-interval)" "sleep wrapper should pause saving"
    assert_file_missing "$TEST_SAVE_LOG"
    assert_process_alive "$(continuum_pid)"
}

main() {
    test_daemon_restarts_cleanly_on_plugin_reload
    test_daemon_starts_when_interval_is_initially_paused
    test_daemon_does_not_save_after_interval_is_paused_during_wait
}

main "$@"
