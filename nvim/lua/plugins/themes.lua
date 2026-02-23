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
  -- Disabled: nvim 0.11+ natively detects OS dark/light mode changes via
  -- terminal mode 2031, making this plugin unnecessary. The plugin also leaks
  -- orphaned `gsettings monitor` processes on every nvim exit.
  -- Limitations of the native feature vs. this plugin:
  --   - Only updates 'background', can't switch between two different colorschemes
  --   - Only works if 'bg' is not explicitly set
  -- See: https://github.com/neovim/neovim/commit/d460928263d0
  --      https://github.com/itsfernn/auto-gnome-theme.nvim/issues/2
  -- {
  --   'itsfernn/auto-gnome-theme.nvim',
  --   lazy = false,
  --   priority = 999,
  --   dependencies = { 'Mofiqul/vscode.nvim' },
  --   config = function()
  --     require('auto-gnome-theme').setup({
  --       theme = 'vscode'
  --     })
  --   end,
  -- },
  { 'RRethy/nvim-base16', lazy = true },
  { 'jschmold/sweet-dark.vim', lazy = true },
  { 'tjdevries/colorbuddy.vim', lazy = true },
  {
    'Th3Whit3Wolf/onebuddy',
    lazy = true,
    dependencies = { 'tjdevries/colorbuddy.vim' },
  },
}
