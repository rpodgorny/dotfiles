return {
  -- LAZY LOADED: ChatGPT
  {
    'jackMort/ChatGPT.nvim',
    cmd = { 'ChatGPT', 'ChatGPTActAs', 'ChatGPTEditWithInstructions' },
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-lua/plenary.nvim',
      'folke/trouble.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require("chatgpt").setup({
        api_key_cmd = "echo '123'",
        api_host_cmd = "echo http://127.0.0.1:1337"
      })
    end,
  },
  {
    'Exafunction/codeium.vim',
    event = "InsertEnter",
    config = function()
      vim.keymap.set('i', '<C-g>', function()
        return vim.fn['codeium#Accept']()
      end, { expr = true })
      vim.keymap.set('i', '<c-;>', function()
        return vim.fn['codeium#CycleCompletions'](1)
      end, { expr = true })
      vim.keymap.set('i', '<c-,>', function()
        return vim.fn['codeium#CycleCompletions'](-1)
      end, { expr = true })
      vim.keymap.set('i', '<c-x>', function()
        return vim.fn['codeium#Clear']()
      end, { expr = true })
    end,
  },
  -- LAZY LOADED: Sniprun
  {
    'michaelb/sniprun',
    build = 'sh ./install.sh',
    cmd = { 'SnipRun', 'SnipRunOperator', 'SnipInfo', 'SnipReset',
            'SnipReplMemoryClean', 'SnipClose', 'SnipLive' },
  },
  -- LAZY LOADED: vim-be-good
  { 'ThePrimeagen/vim-be-good', cmd = 'VimBeGood' },
}
