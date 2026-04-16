#!/usr/bin/env bash

TEST_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT_DIR="$(cd "$TEST_HELPERS_DIR/../.." && pwd)"
TEST_ORIGINAL_PATH="$PATH"
TEST_ORIGINAL_SHELL="${SHELL:-}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
}

setup_test_env() {
    teardown_test_env

    require_command tmux

    TEST_REAL_TMUX="$(command -v tmux)"
    TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/tmux-continuum-test.XXXXXX")"
    TEST_HOME="$TEST_TMPDIR/home"
    TEST_XDG_CONFIG_HOME="$TEST_TMPDIR/config"
    TEST_XDG_DATA_HOME="$TEST_TMPDIR/data"
    TEST_XDG_STATE_HOME="$TEST_TMPDIR/state"
    TEST_BIN="$TEST_TMPDIR/bin"
    TEST_TMUX_SOCKET="$TEST_TMPDIR/tmux.sock"

    mkdir -p "$TEST_HOME" "$TEST_XDG_CONFIG_HOME" "$TEST_XDG_DATA_HOME" "$TEST_XDG_STATE_HOME" "$TEST_BIN"

    cat > "$TEST_BIN/tmux" <<'TMUX_WRAPPER'
#!/usr/bin/env bash
exec "$TEST_REAL_TMUX" -f /dev/null -S "$TEST_TMUX_SOCKET" "$@"
TMUX_WRAPPER
    chmod +x "$TEST_BIN/tmux"

    export TEST_REAL_TMUX TEST_TMPDIR TEST_HOME TEST_XDG_CONFIG_HOME TEST_XDG_DATA_HOME
    export TEST_XDG_STATE_HOME TEST_BIN TEST_TMUX_SOCKET
    export HOME="$TEST_HOME"
    export XDG_CONFIG_HOME="$TEST_XDG_CONFIG_HOME"
    export XDG_DATA_HOME="$TEST_XDG_DATA_HOME"
    export XDG_STATE_HOME="$TEST_XDG_STATE_HOME"
    export PATH="$TEST_BIN:$TEST_ORIGINAL_PATH"
    export SHELL=/bin/sh
}

teardown_test_env() {
    if [ -n "${TEST_TMUX_SOCKET:-}" ] && [ -n "${TEST_REAL_TMUX:-}" ]; then
        local pid
        pid="$("$TEST_REAL_TMUX" -f /dev/null -S "$TEST_TMUX_SOCKET" show-option -gqv @_continuum_pid 2>/dev/null || true)"
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
        "$TEST_REAL_TMUX" -f /dev/null -S "$TEST_TMUX_SOCKET" kill-server >/dev/null 2>&1 || true
    fi

    if [ -n "${TEST_TMPDIR:-}" ]; then
        rm -rf "$TEST_TMPDIR"
    fi

    unset TEST_REAL_TMUX TEST_TMPDIR TEST_HOME TEST_XDG_CONFIG_HOME TEST_XDG_DATA_HOME
    unset TEST_XDG_STATE_HOME TEST_BIN TEST_TMUX_SOCKET TEST_SAVE_LOG TEST_RESTORE_LOG
    unset TEST_FAKE_SAVE_SCRIPT TEST_FAKE_RESTORE_SCRIPT
    export PATH="$TEST_ORIGINAL_PATH"

    if [ -n "$TEST_ORIGINAL_SHELL" ]; then
        export SHELL="$TEST_ORIGINAL_SHELL"
    else
        unset SHELL
    fi
}

install_fake_resurrect_scripts() {
    TEST_SAVE_LOG="$TEST_TMPDIR/save.log"
    TEST_RESTORE_LOG="$TEST_TMPDIR/restore.log"
    TEST_FAKE_SAVE_SCRIPT="$TEST_TMPDIR/resurrect-save"
    TEST_FAKE_RESTORE_SCRIPT="$TEST_TMPDIR/resurrect-restore"

    local save_log restore_log
    printf -v save_log '%q' "$TEST_SAVE_LOG"
    printf -v restore_log '%q' "$TEST_RESTORE_LOG"

    cat > "$TEST_FAKE_SAVE_SCRIPT" <<SAVE_SCRIPT
#!/usr/bin/env bash
printf '%s\n' "\$*" >> $save_log
SAVE_SCRIPT

    cat > "$TEST_FAKE_RESTORE_SCRIPT" <<RESTORE_SCRIPT
#!/usr/bin/env bash
printf 'restore\n' >> $restore_log
RESTORE_SCRIPT

    chmod +x "$TEST_FAKE_SAVE_SCRIPT" "$TEST_FAKE_RESTORE_SCRIPT"
    export TEST_SAVE_LOG TEST_RESTORE_LOG TEST_FAKE_SAVE_SCRIPT TEST_FAKE_RESTORE_SCRIPT
}

install_sleep_wrapper_that_pauses_interval() {
    local count_file
    count_file="$TEST_TMPDIR/sleep-count"

    local count_file_q
    printf -v count_file_q '%q' "$count_file"

    cat > "$TEST_BIN/sleep" <<SLEEP_WRAPPER
#!/usr/bin/env bash
count="\$(cat $count_file_q 2>/dev/null || echo 0)"
count="\$((count + 1))"
printf '%s' "\$count" > $count_file_q
if [ "\$count" -eq 1 ]; then
    tmux set-option -gq @continuum-save-interval 0 >/dev/null 2>&1 || true
fi
exec /bin/sleep 0.05
SLEEP_WRAPPER
    chmod +x "$TEST_BIN/sleep"
}

start_tmux_server() {
    local session="${1:-main}"
    tmux new-session -d -s "$session" -n main
}

configure_continuum() {
    local interval="${1:-0}"
    local restore="${2:-off}"

    tmux set-option -gq @resurrect-save-script-path "$TEST_FAKE_SAVE_SCRIPT"
    tmux set-option -gq @resurrect-restore-script-path "$TEST_FAKE_RESTORE_SCRIPT"
    tmux set-option -gq @continuum-save-interval "$interval"
    tmux set-option -gq @continuum-restore "$restore"
}

run_continuum() {
    tmux run-shell "$TEST_ROOT_DIR/continuum.tmux"
}

continuum_pid() {
    tmux show-option -gqv @_continuum_pid 2>/dev/null || true
}

process_alive() {
    local pid="$1"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

process_dead() {
    ! process_alive "$1"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        fail "$message: expected [$expected], got [$actual]"
    fi
}

assert_nonempty() {
    local value="$1"
    local message="$2"
    [ -n "$value" ] || fail "$message"
}

assert_process_alive() {
    local pid="$1"
    process_alive "$pid" || fail "expected live process: $pid"
}

assert_file_exists() {
    local file="$1"
    [ -f "$file" ] || fail "missing file: $file"
}

assert_file_missing() {
    local file="$1"
    [ ! -e "$file" ] || fail "unexpected file exists: $file"
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    [[ "$haystack" == *"$needle"* ]] || fail "$message: missing [$needle]"
}

assert_not_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    [[ "$haystack" != *"$needle"* ]] || fail "$message: unexpected [$needle]"
}

wait_for() {
    local description="$1"
    shift
    local attempts=50

    until "$@"; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            fail "timed out waiting for $description"
        fi
        /bin/sleep 0.1
    done
}
