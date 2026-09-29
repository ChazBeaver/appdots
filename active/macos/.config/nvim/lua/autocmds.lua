-- Flash the yanked text so copies give visible feedback
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})
