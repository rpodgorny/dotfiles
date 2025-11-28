-- OpenSCAD filetype detection
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*.scad",
  callback = function()
    vim.bo.filetype = "openscad"
  end,
})

-- Highlight trailing whitespace
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "#FF0000" })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
  end,
})
