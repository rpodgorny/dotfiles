return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = "all",
        ignore_install = { "ipkg" }, -- Skip problematic parsers
        highlight = { enable = true },
      })
    end,
  },
}
