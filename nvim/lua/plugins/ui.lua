return {
  {
    'nvim-lualine/lualine.nvim',
    event = "VeryLazy",
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          section_separators = '',
          component_separators = ''
        },
        sections = {
          lualine_a = {
            { 'mode', fmt = function(mode) return mode:sub(1, 1) end }
          },
          lualine_b = { 'diagnostics' },
          lualine_c = { 'filename', 'nvim_treesitter#statusline' },
          lualine_x = {
            function()
              return require('lsp-status').status()
            end,
            'filetype'
          },
        }
      })
    end,
  },
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  {
    'norcalli/nvim-colorizer.lua',
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('colorizer').setup()
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    tag = '*',
    keys = {
      { '<c-\\>', mode = { 'n', 't' }, desc = 'Toggle terminal' },
    },
    config = function()
      require("toggleterm").setup({
        open_mapping = [[<c-\>]],
      })
    end,
  },
}
