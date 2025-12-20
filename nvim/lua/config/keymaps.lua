-- Leader keys set in init.lua before lazy loads
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Navigation
map('n', '<Up>', 'gk', opts)
map('n', '<Down>', 'gj', opts)
map('n', '<M-o>', '<C-w>w', opts)
map('n', '<C-d>', '<C-d>zz', opts)
map('n', '<C-u>', '<C-u>zz', opts)

-- Telescope (handled by lazy.nvim in lua/plugins/navigation.lua)
-- map('n', '<leader>C', '<cmd>Telescope commands<cr>', opts)
-- map('n', '<leader>d', '<cmd>Telescope diagnostics<cr>', opts)
-- map('n', '<leader>f', '<cmd>Telescope find_files<cr>', opts)
-- map('n', '<leader>/', '<cmd>Telescope live_grep<cr>', opts)
-- map('n', '<leader>?', '<cmd>Telescope grep_string<cr>', opts)
-- map('n', '<leader>b', '<cmd>Telescope buffers<cr>', opts)
-- map('n', '<leader>H', '<cmd>Telescope help_tags<cr>', opts)  -- Changed from <leader>h
-- map('n', '<leader>s', '<cmd>Telescope lsp_document_symbols<cr>', opts)
-- map('n', '<leader>S', '<cmd>Telescope lsp_workspace_symbols<cr>', opts)
-- map('n', 'gr', '<cmd>Telescope lsp_references<cr>', opts)
-- map('n', 'gd', '<cmd>Telescope lsp_definitions<cr>', opts)

-- LSP
map('n', '<leader>F', vim.lsp.buf.format, opts)
map('n', '<leader>i', function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, opts)

-- Comment mapping is handled by lazy.nvim in lua/plugins/editing.lua

-- Quote swapping
map('n', '<leader>\'', 'mqva"l:s/\\%V"\\%V/\'/g<CR>`q', { noremap = true, silent = false })
map('n', '<leader>"', 'mqva\'l:s/\\%V\'\\%V/"/g<CR>`q', { noremap = true, silent = false })
map('v', '<leader>\'', '<Esc>`>a\'<Esc>`<i\'<Esc>', opts)
map('v', '<leader>"', '<Esc>`>a"<Esc>`<i"<Esc>', opts)

-- Theme toggle
map('n', '<Leader>T', function()
  if vim.o.background == "dark" then
    vim.o.background = "light"
  else
    vim.o.background = "dark"
  end
end, opts)

-- Buffer (barbar was commented out, keeping for reference)
map('n', '<leader>cc', '<cmd>BufferClose<cr>', opts)
