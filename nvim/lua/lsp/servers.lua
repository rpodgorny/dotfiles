-- TODO: this can be probably simplified
local capabilities = vim.tbl_deep_extend(
  'force',
  require('cmp_nvim_lsp').default_capabilities(),
  {}
)

-- Add borders to LSP floating windows
local border_style = "rounded"  -- Options: "single", "double", "rounded", "solid", "shadow"

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
  vim.lsp.handlers.hover, {
    border = border_style,
  }
)

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.handlers.signature_help, {
    border = border_style,
  }
)

local on_attach = function(client, bufnr)
  local bufopts = { noremap = true, silent = true, buffer = bufnr }

  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', '<leader>F', vim.lsp.buf.format, bufopts)
end

-- Configure default capabilities and on_attach
vim.lsp.config('*', {
  capabilities = capabilities,
  on_attach = on_attach,
})

-- Python LSP - Ruff (linting & formatting)
vim.lsp.config('ruff', {
  cmd = { 'ruff', 'server' },
  settings = {
    lineLength = 9999,
    lint = {
      enable = true,
    },
    format = {
      enable = true,
    },
  }
})

-- Python LSP - Pyright (semantic features: hover, go-to-def, completion)
vim.lsp.config('pyright', {
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "off",  -- Disable strict type checking (ruff handles linting)
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      }
    }
  }
})

-- Rust LSP
vim.lsp.config('rust_analyzer', {
  settings = {
    ['rust-analyzer'] = {
      diagnostics = { enable = false }
    }
  }
})

-- Enable LSP servers
vim.lsp.enable('ruff')       -- Python linting/formatting
vim.lsp.enable('pyright')    -- Python semantic features
vim.lsp.enable('rust_analyzer')
vim.lsp.enable('clangd')
vim.lsp.enable('cssls')
vim.lsp.enable('ts_ls')
vim.lsp.enable('tailwindcss')
vim.lsp.enable('gopls')
vim.lsp.enable('openscad_ls')

-- Diagnostics config
vim.diagnostic.config({
  virtual_lines = { current_line = true },
  float = {
    border = border_style,
  },
})
