export PATH=~/bin:~/scripts:${PATH}

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# should be handled by the lines above
#systemctl --user import-environment DISPLAY XAUTHORITY

xset +fp /usr/share/fonts/local
xset fp rehash

# shouldn't this be done automatically by x server or something?
xrdb -merge ~/.Xresources

xrandr --dpi 120x120

setxkbmap -option 'ctrl:nocaps'
#setxkbmap -layout us,cz -variant ,qwerty -option -option grp:alt_shift_toggle =option grp_led:scroll

dex -av -e i3

#LOCK="i3lock -c 555555"
#${LOCK}
#xss-lock -- ${LOCK} &

# if you omit the fork and sleep, xbindkeys will eat all keyboard input
#`sleep 10; xbindkeys` &

# keep turning the mouse off
#`while true; do xinput set-prop 6 272 1; sleep 10; done` &

#`sleep 10; xterm` &

#exec i3
exec sway
