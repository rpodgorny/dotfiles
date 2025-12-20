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
    'kosayoda/nvim-lightbulb',
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { 'antoinemadec/FixCursorHold.nvim' },
    config = function()
      require('nvim-lightbulb').setup({ autocmd = { enabled = true } })
    end,
  },
}
