#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/test_helpers.sh
source "$CURRENT_DIR/helpers/test_helpers.sh"

trap teardown_test_env EXIT

render_systemd_unit() {
    eval "$(sed '$d' "$TEST_ROOT_DIR/scripts/boot/systemd.sh")"
    generate_unit
}

test_systemd_unit_starts_tmux_without_owning_server_shutdown() {
    setup_test_env

    local unit
    unit="$(render_systemd_unit)"

    assert_contains "Type=oneshot" "$unit" "systemd unit should be a startup trigger"
    assert_contains "RemainAfterExit=yes" "$unit" "systemd unit should stay active after startup"
    assert_contains "ExecStart=" "$unit" "systemd unit should start tmux"
    assert_not_contains "ExecStop=" "$unit" "systemd unit should not kill the tmux server"
    assert_not_contains "kill-server" "$unit" "systemd unit should not own tmux shutdown"
}

main() {
    test_systemd_unit_starts_tmux_without_owning_server_shutdown
}

main "$@"
