# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/radek/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

prompt_gentoo_setup () {
	prompt_gentoo_prompt=${1:-'blue'}
	prompt_gentoo_user=${2:-'green'}
	prompt_gentoo_root=${3:-'red'}

	if [ "$USER" = 'root' ];
	then
		base_prompt="%B%F{$prompt_gentoo_root}%m%k "
	else
		base_prompt="%B%F{$prompt_gentoo_user}%n@%m%k "
	fi
	post_prompt="%b%f%k"

	#setopt noxtrace localoptions

	path_prompt="%B%F{$prompt_gentoo_prompt}%1~"
	PS1="$base_prompt$path_prompt %# $post_prompt"
	PS2="$base_prompt$path_prompt %_> $post_prompt"
	PS3="$base_prompt$path_prompt ?# $post_prompt"
}

prompt_gentoo_setup "$@"

#autoload -U promptinit
#promptinit
#prompt gentoo
#prompt suse

export TERM=linux
export EDITOR=vim
export PATH=~/bin:/sbin:/usr/sbin:${PATH}
