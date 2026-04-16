#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/test_helpers.sh
source "$CURRENT_DIR/helpers/test_helpers.sh"

trap teardown_test_env EXIT

test_restore_runs_on_fresh_default_server() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    configure_continuum 0 on

    run_continuum

    wait_for "restore marker" test -f "$TEST_RESTORE_LOG"
    assert_eq "1" "$(tmux show-option -gqv @_continuum_restored)" "restore decision flag"
}

test_restore_skips_server_that_already_has_user_state() {
    setup_test_env
    install_fake_resurrect_scripts
    start_tmux_server
    tmux new-window -d
    configure_continuum 0 on

    run_continuum
    /bin/sleep 1.2

    assert_file_missing "$TEST_RESTORE_LOG"
    assert_eq "1" "$(tmux show-option -gqv @_continuum_restored)" "skipped restore should still set flag"
}

main() {
    test_restore_runs_on_fresh_default_server
    test_restore_skips_server_that_already_has_user_state
}

main "$@"
