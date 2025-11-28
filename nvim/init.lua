-- Set leader keys BEFORE loading lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load configuration
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
