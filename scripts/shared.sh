current_timestamp() {
	echo "$(date +%s)"
}

get_auto_save_interval() {
	local interval
	interval="$(get_tmux_option "$auto_save_interval_option" "$auto_save_interval_default")"

	case "$interval" in
		''|*[!0-9]*)
			echo "$auto_save_interval_default"
			;;
		*)
			echo "$interval"
			;;
	esac
}

set_last_save_timestamp() {
	set_tmux_option "$last_auto_save_option" "$(current_timestamp)"
}
