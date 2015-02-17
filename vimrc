set nocompatible
set encoding=utf-8

" this has to be before 'ruler' (and maybe others) - why???
" actually don't set this as it conflicts with youcompleteme tab completion
" set paste

set ruler
set laststatus=2
set showcmd
set showmode
"set number

" better search
set incsearch
set ignorecase
set smartcase
set hlsearch

set scrolloff=5

set listchars=tab:>-,trail:-,nbsp:%,eol:$

filetype plugin on
filetype plugin indent off
set autoindent
set nocindent
set noexpandtab
set tabstop=4
set shiftwidth=4

" show trailing whitespace
" http://vim.wikia.com/wiki/Highlight_unwanted_spaces
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

syntax on
set background=dark

inoremap <Up> <NOP>
inoremap <Down> <NOP>
inoremap <Left> <NOP>
inoremap <Right> <NOP>
noremap <Up> <NOP>
noremap <Down> <NOP>
noremap <Left> <NOP>
noremap <Right> <NOP>
