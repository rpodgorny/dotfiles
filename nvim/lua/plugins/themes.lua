return {
  { 'projekt0n/github-nvim-theme', lazy = true },
  { 'UtkarshVerma/molokai.nvim', branch = 'main', lazy = true },
  {
    'Mofiqul/vscode.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd('colorscheme vscode')
    end,
  },
  { 'RRethy/nvim-base16', lazy = true },
  { 'jschmold/sweet-dark.vim', lazy = true },
  { 'tjdevries/colorbuddy.vim', lazy = true },
  {
    'Th3Whit3Wolf/onebuddy',
    lazy = true,
    dependencies = { 'tjdevries/colorbuddy.vim' },
  },
}
