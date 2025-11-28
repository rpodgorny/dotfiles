return {
  {
    'neovim/nvim-lspconfig',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { 'nvim-lua/lsp-status.nvim' },
    config = function()
      require('lsp.servers')
    end,
  },
  {
    'nvim-lua/lsp-status.nvim',
    lazy = true,
    config = function()
      local lsp_status = require('lsp-status')
      lsp_status.config({
        current_function = true,
        show_filename = true
      })
      lsp_status.register_progress()
    end,
  },
  {
    'kosayoda/nvim-lightbulb',
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { 'antoinemadec/FixCursorHold.nvim' },
    config = function()
      require('nvim-lightbulb').setup({ autocmd = { enabled = true } })
    end,
  },
}
