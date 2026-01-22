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

-- TODO: can't this be merged with the above somehow?
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("match ExtraWhitespace /\\s\\+$/")
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "#FF0000" })
  end,
})
