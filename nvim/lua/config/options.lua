local opt = vim.opt

-- UI
opt.termguicolors = true
opt.background = "dark"
opt.encoding = "utf-8"
opt.mouse = ""
opt.signcolumn = "yes"

-- Editor
opt.path:append("**")
opt.wildmenu = true
opt.ruler = true
opt.laststatus = 2
opt.showcmd = true
opt.showmode = true
opt.scrolloff = 5
opt.breakindent = true
opt.listchars = { tab = ">-", trail = "-", nbsp = "%", eol = "$" }

-- Search
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true

-- Indentation
opt.autoindent = true
opt.cindent = false
opt.expandtab = false
opt.tabstop = 4
opt.shiftwidth = 4

-- Enable syntax and filetype
vim.cmd("syntax enable")
vim.cmd("filetype plugin on")
vim.cmd("filetype plugin indent off")

-- Set default border for all floating windows
vim.opt.pumblend = 0  -- Popup menu transparency
local border_style = "rounded"

-- Override default border for floating windows
local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = opts.border or border_style
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end
