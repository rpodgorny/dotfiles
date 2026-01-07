return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('nvim-treesitter').setup({
        ---ensure_installed = "all",
        ensure_installed = { "lua", "vim", "vimdoc", "c", "rust", "python", "javascript", "typescript", "html", "css", "json" },
        ---ignore_install = { "ipkg" }, -- Skip problematic parsers
        highlight = { enable = true },
      })
    end,
  },
}
