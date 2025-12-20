return {
  {
    'nvim-telescope/telescope.nvim',
    tag = 'v0.2.0',
    cmd = 'Telescope',
    keys = {
      { '<leader>C', '<cmd>Telescope commands<cr>' },
      { '<leader>d', '<cmd>Telescope diagnostics<cr>' },
      { '<leader>f', '<cmd>Telescope find_files<cr>' },
      { '<leader>/', '<cmd>Telescope live_grep<cr>' },
      { '<leader>?', '<cmd>Telescope grep_string<cr>' },
      { '<leader>b', '<cmd>Telescope buffers<cr>' },
      { '<leader>H', '<cmd>Telescope help_tags<cr>' },
      { '<leader>s', '<cmd>Telescope lsp_document_symbols<cr>' },
      { '<leader>S', '<cmd>Telescope lsp_workspace_symbols<cr>' },
      { 'gr', '<cmd>Telescope lsp_references<cr>' },
      { 'gd', '<cmd>Telescope lsp_definitions<cr>' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      's1n7ax/nvim-window-picker',
    },
    config = function()
      require('telescope').setup({
        defaults = {
          path_display = { "smart" },
          scroll_strategy = "limit",
          layout_config = { width = 0.99 },
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },  -- Rounded borders
          mappings = {
            i = {
              ["<C-h>"] = "which_key",
              ["<C-w>"] = function(prompt_bufnr)
                local action_set = require('telescope.actions.set')
                local action_state = require('telescope.actions.state')
                local picker = action_state.get_current_picker(prompt_bufnr)
                picker.get_selection_window = function(picker, entry)
                  local picked_window_id = require('window-picker').pick_window()
                    or vim.api.nvim_get_current_win()
                  picker.get_selection_window = nil
                  return picked_window_id
                end
                return action_set.edit(prompt_bufnr, 'edit')
              end,
            },
          },
        },
        extensions = {
          ["ui-select"] = { require("telescope.themes").get_dropdown() }
        }
      })
      require("telescope").load_extension("ui-select")
    end,
  },
  { 'nvim-telescope/telescope-ui-select.nvim', lazy = true },
  {
    's1n7ax/nvim-window-picker',
    -- tag = 'v2.4.0',
    lazy = true,
    config = function()
      require('window-picker').setup({
        hint = 'floating-big-letter',
        filter_rules = { include_current_win = true }
      })
    end,
  },
  {
    'phaazon/hop.nvim',
    keys = { { '<leader>h', '<cmd>HopWord<cr>' } },
    config = function()
      require('hop').setup()
    end,
  },
  {
    'ggandor/leap.nvim',
    keys = { 's', 'S', 'gs' },
    config = function()
      require('leap').set_default_keymaps()
    end,
  },
  {
    'folke/which-key.nvim',
    event = "VeryLazy",
    opts = {
      preset = "classic",
      win = {
        border = "rounded",
      },
    },
  },
}
