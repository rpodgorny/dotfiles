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
  {
    'itsfernn/auto-gnome-theme.nvim',
    lazy = false,  -- Load at startup to monitor system theme
    priority = 999,  -- Load just before vscode theme (which has priority 1000)
    dependencies = { 'Mofiqul/vscode.nvim' },  -- Ensure vscode theme is available
    config = function()
      require('auto-gnome-theme').setup({
        theme = 'vscode'  -- Use vscode theme which has built-in light/dark variants
      })
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
