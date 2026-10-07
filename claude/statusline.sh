#!/bin/bash
# statusline: context window usage + caveman badge + skills used this session
in=$(cat)

# context window
printf '%s' "$in" | jq -j '
  .context_window // empty
  | (if .total_input_tokens > 120000 then 196
     elif .total_input_tokens > 100000 then 220
     else 110 end) as $c
  | "[38;5;\($c)m\((.total_input_tokens/1000)|floor)k/\((.context_window_size/1000)|floor)k (\(.used_percentage|round)%)[0m"
'

# caveman plugin badge (install path has a version hash -> glob it)
for s in "$HOME"/.claude/plugins/cache/caveman/caveman/*/src/hooks/caveman-statusline.sh; do
  [ -f "$s" ] && printf ' ' && bash "$s" && break
done

# skills invoked this session (from transcript)
tp=$(printf '%s' "$in" | jq -r '.transcript_path // empty')
if [ -n "$tp" ] && [ -f "$tp" ]; then
  skills=$(grep -o '"skill":"[^"]*"' "$tp" | cut -d'"' -f4 | sort -u | paste -sd, -)
  [ -n "$skills" ] && printf ' \033[38;5;108m[%s]\033[0m' "$skills"
fi

exit 0
