#!/usr/bin/env bash

halt_file="${TMUX_CONTINUUM_NO_RESTORE:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux/no-auto-restore}"
[[ -f "$halt_file" ]] && exit 0

# Let other plugins finish loading
sleep 1

restore_script="$(tmux show-option -gqv @_continuum_restore_script 2>/dev/null)"
if [[ -n "$restore_script" && -x "$restore_script" ]]; then
    # Resurrect reports restore-specific failures; keep tmux from showing a generic run-shell error.
    "$restore_script" || true
fi

exit 0
