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

test_plugin_script_paths_are_shell_quoted() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    configure_continuum 0 on
    tmux set-option -gq status-right 'Continuum: #{continuum_status}'

    local plugin_dir boot_log boot_log_quoted
    plugin_dir="$TEST_TMPDIR/plugin with spaces and ' quote"
    boot_log="$TEST_TMPDIR/boot.log"
    boot_log_quoted="$(test_shell_quote "$boot_log")"

    mkdir -p "$plugin_dir"
    plugin_dir="$(cd "$plugin_dir" && pwd)"
    cp "$TEST_ROOT_DIR/continuum.tmux" "$plugin_dir/continuum.tmux"
    cp -R "$TEST_ROOT_DIR/scripts" "$plugin_dir/scripts"
    cat > "$plugin_dir/scripts/boot/setup.sh" <<FAKE_BOOT
#!/usr/bin/env bash
printf '%s\n' "\$*" >> $boot_log_quoted
FAKE_BOOT
    chmod +x "$plugin_dir/scripts/boot/setup.sh"

    tmux run-shell "$(test_shell_quote "$plugin_dir/continuum.tmux")"

    local pid
    pid="$(continuum_pid)"
    assert_nonempty "$pid" "daemon pid should be set when plugin path contains shell-special characters"
    assert_process_alive "$pid"

    wait_for "restore marker from shell-quoted plugin path" test -f "$TEST_RESTORE_LOG"

    tmux continuum-boot-enable
    wait_for "boot command from shell-quoted plugin path" test -f "$boot_log"
    assert_contains "enable" "$(< "$boot_log")" "boot command should run from shell-quoted plugin path"

    local status_right expected_status_command
    status_right="$(tmux show-option -gqv status-right)"
    expected_status_command="#($(test_shell_quote "$plugin_dir/scripts/status.sh"))"

    assert_contains "$expected_status_command" "$status_right" "status command should shell-quote plugin path"
}

main() {
    test_daemon_restarts_cleanly_on_plugin_reload
    test_daemon_starts_when_interval_is_initially_paused
    test_daemon_does_not_save_after_interval_is_paused_during_wait
    test_plugin_script_paths_are_shell_quoted
}

main "$@"
