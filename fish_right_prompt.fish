function fish_right_prompt
	set_color yellow

	if set -q CMD_DURATION
		echo "(+$CMD_DURATION)" (date "+%Y-%m-%d %H:%M:%S")
	else
		date "+%Y-%m-%d %H:%M:%S"
	end
end
