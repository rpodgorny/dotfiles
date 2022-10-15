set nocompatible


set termguicolors
set background=dark

set encoding=utf-8
syntax enable

" this fucks up 'select to copy' functionality in terminal
" set mouse+=a

" disable mouse shit to enable middle-button paste
set mouse=

set path+=**
set wildmenu

" this has to be before 'ruler' (and maybe others) - why???
" actually don't set this as it conflicts with youcompleteme tab completion
" set paste

set ruler
set laststatus=2
set showcmd
set showmode
" set number
" set relativenumber
" set nowrap

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

" show trailing whitespace - TODO does not seem to work in javascript (maybe has something to do with lsp? or treesitter?)
" https://vim.wikia.com/wiki/Highlight_unwanted_spaces
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

" do not skip wrapped lines (does not work in insert mode)
" inoremap <Up> gk
" inoremap <Down> gj
nnoremap <Up> gk
nnoremap <Down> gj

nnoremap <M-o> <C-w>w

call plug#begin()

Plug 'neovim/nvim-lspconfig'

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', {'tag': '0.1.0'}

Plug 'nvim-telescope/telescope-ui-select.nvim'

Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'L3MON4D3/LuaSnip'

" Plug 'jiangmiao/auto-pairs'

Plug 'kosayoda/nvim-lightbulb'
Plug 'antoinemadec/FixCursorHold.nvim'

Plug 'kyazdani42/nvim-web-devicons'
Plug 'romgrk/barbar.nvim'

" Plug 'tpope/vim-sleuth'
Plug 'nmac427/guess-indent.nvim'

Plug 'farmergreg/vim-lastplace'

Plug 'phaazon/hop.nvim'
Plug 'ggandor/leap.nvim'

Plug 'folke/which-key.nvim'

Plug 'norcalli/nvim-colorizer.lua'

Plug 'projekt0n/github-nvim-theme'
Plug 'UtkarshVerma/molokai.nvim', {'branch': 'main'}
Plug 'Mofiqul/vscode.nvim'
Plug 'RRethy/nvim-base16'
Plug 'jschmold/sweet-dark.vim'

Plug 'tjdevries/colorbuddy.vim'
Plug 'Th3Whit3Wolf/onebuddy'

call plug#end()

lua <<EOF

local opts = { noremap=true, silent=true }
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  --vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<space>f', vim.lsp.buf.formatting, bufopts)
end

require'lspconfig'.pylsp.setup{
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = {'W191', 'E122', 'E265'},
          maxLineLength = 9999
        },
        mccabe = {
          enabled = false
        }
      }
    }
  }
}
require'lspconfig'.rust_analyzer.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
require'lspconfig'.tsserver.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}
require'lspconfig'.gopls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
}

local luasnip = require 'luasnip'
local cmp = require 'cmp'
cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  sources = {
    {name = 'nvim_lua'},
    {name = 'nvim_lsp'},
    --{name = 'path'},
    --{name = 'luasnip'},
    {name = 'buffer', keyword_length = 5},
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
}

require('nvim-lightbulb').setup({autocmd = {enabled = true}})

require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true
  }
}

require'telescope'.setup {
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown{}
    }
  }
}
require("telescope").load_extension("ui-select")

require'colorizer'.setup()

require("which-key").setup {}

require('guess-indent').setup {}

require("bufferline").setup {
  auto_hide = true,
}

require'hop'.setup()

vim.api.nvim_set_keymap('', 'f', "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>", {})
vim.api.nvim_set_keymap('', 'F', "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>", {})
vim.api.nvim_set_keymap('', 't', "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })<cr>", {})
vim.api.nvim_set_keymap('', 'T', "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })<cr>", {})

require('leap').set_default_keymaps()

--require('vscode').setup({
--  color_overrides = {
--    vscBack = '#000000',
--  }
--})

EOF

colorscheme vscode

let mapleader = " "

nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fG <cmd>Telescope grep_string<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
nnoremap <leader>gr <cmd>Telescope lsp_references<cr>

nnoremap <leader>h <cmd>HopWord<cr>
nnoremap <leader>c <cmd>BufferClose<cr>

" open file at last position (doesn't seem to be working)
" autocmd BufRead * autocmd FileType ++once if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif

" autocmd FileType python "Sleuth<CR>"
