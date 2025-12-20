return {
  {
    'terrortylor/nvim-comment',
    keys = {
      { '<M-/>', '<cmd>CommentToggle<cr>', mode = 'n' },
      { '<M-/>', ":<C-u>:'<,'>CommentToggle<cr>", mode = 'v' },
    },
    config = function()
      require('nvim_comment').setup()
    end,
  },
  {
    'nmac427/guess-indent.nvim',
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('guess-indent').setup()
    end,
  },
  { 'farmergreg/vim-lastplace', event = "BufReadPost" },
}
