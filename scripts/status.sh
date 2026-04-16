#!/usr/bin/env bash

interval="$(tmux show-option -gqv @continuum-save-interval 2>/dev/null)"
[[ ! "$interval" =~ ^[0-9]+$ ]] && interval=15

last_save="$(tmux show-option -gqv @continuum-last-save 2>/dev/null)"

if [[ "$interval" -eq 0 ]]; then
    echo "off"
elif [[ -n "$last_save" ]]; then
    elapsed="$(( $(date +%s) - last_save ))"
    echo "$((elapsed / 60))m ago"
else
    echo "${interval}m"
fi
