### FAQ

> Will a previous save be overwritten immediately after I start tmux?

No, the first automatic save happens after the configured interval (15 minutes
by default). If automatic restore is not enabled, that gives you enough time to
manually restore from a previous save.

> I want to make a restore to a previous point in time, but it seems that save
is now overwritten?

Read how to [restore a previously saved environment](https://github.com/tmux-plugins/tmux-resurrect/blob/master/docs/restoring_previously_saved_environment.md)

> Will this plugin fill my hard disk?

Most likely no. A regular save file is in the range of 5Kb. And `tmux-resurrect` already has a `remove_old_backups()` routine that will ["remove resurrect files older than 30 days, but keep at least 5 copies of backup."](https://github.com/tmux-plugins/tmux-resurrect/blob/da1a7558024b8552f7262b39ed22e3d679304f99/scripts/save.sh#L271-L277)

> How do I change the save interval to i.e. 1 hour?

The interval is always measured in minutes. So setting the interval to `60`
(minutes) will do the trick. Put this in `.tmux.conf`:

    set -g @continuum-save-interval '60'

and then source `tmux.conf` by executing this command in the shell
`$ tmux source-file ~/.tmux.conf`.

> How do I stop automatic saving?

Set the save interval to `0`. Put this in `.tmux.conf`:

    set -g @continuum-save-interval '0'

The change takes effect within 60 seconds — no need to re-source your config.
To re-enable, set the interval back to a positive number.

> I had automatic restore turned on, how do I disable it now?

Remove `set -g @continuum-restore 'on'` from `tmux.conf`.

To be absolutely sure automatic restore doesn't happen, create a halt file:

    mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
    touch "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/no-auto-restore"

Automatic restore won't happen if this file exists. You can override the path
with the `TMUX_CONTINUUM_NO_RESTORE` environment variable.

> How do I check if the save daemon is running?

Check the PID stored in the tmux option:

    tmux show-option -gv @_continuum_pid

Verify the process is alive:

    kill -0 $(tmux show-option -gv @_continuum_pid) && echo "running" || echo "dead"

The `#{continuum_status}` interpolation also makes this visible — if the "Xm
ago" number keeps growing beyond the save interval, the daemon has likely
stopped. Re-sourcing `.tmux.conf` will restart it.
