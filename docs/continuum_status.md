## Continuum status in tmux status line

You can display the current status of tmux-continuum in the tmux status line
using the `#{continuum_status}` interpolation. It works with both `status-right`
and `status-left`.

Example usage:

    set -g status-right 'Continuum: #{continuum_status}'

The interpolation shows:

- **`3m ago`** — last save was 3 minutes ago (confirms saving is working)
- **`15m`** — the configured interval, shown before the first save has completed
- **`off`** — saving is disabled (interval is `0`)

If you want to style the output, wrap it with tmux style tags directly:

    set -g status-right '#[fg=green]#{continuum_status}#[default]'
