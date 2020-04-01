if test -d ~/bin
  set -x PATH ~/bin/ $PATH
end
if test -d ~/scripts
  set -x PATH ~/scripts/ $PATH
end

set -x EDITOR vim

alias r=retry
alias ytdl=youtube-dl
alias btdl='transmission-cli -w .'
alias sshnv='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

set fish_greeting

set fish_color_autosuggestion '555' 'yellow'
#set fish_color_command '005fd7' 'purple'
set fish_color_command '60bfff' 'purple' '--bold'
set fish_color_comment red
set fish_color_cwd green
set fish_color_cwd_root red
set fish_color_error 'red' '--bold'
set fish_color_escape cyan
set fish_color_history_current cyan
set fish_color_host '-o' 'cyan'
set fish_color_match cyan
set fish_color_normal normal
set fish_color_operator cyan
set fish_color_param '00afff' 'cyan'
set fish_color_quote brown
set fish_color_redirection normal
set fish_color_search_match --background=purple
set fish_color_status red
set fish_color_user '-o' 'green'
set fish_color_valid_path --underline

if test -f /usr/share/autojump/autojump.fish
  source /usr/share/autojump/autojump.fish
end
