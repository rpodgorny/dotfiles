function fish_right_prompt
	set_color yellow

	if set -q CMD_DURATION
		#echo "(+$CMD_DURATION)" (date "+%Y-%m-%d %H:%M:%S")
		set secs (math "$CMD_DURATION / 1000")
		set formatted (date -u -d @$secs "+%H:%M:%S")
		echo "(+$formatted)" (date "+%Y-%m-%d %H:%M:%S")
	else
		date "+%Y-%m-%d %H:%M:%S"
	end
end
