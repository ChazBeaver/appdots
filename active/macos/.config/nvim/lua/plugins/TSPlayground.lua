return {
  "nvim-treesitter/playground",
  cmd = {
    "TSPlaygroundToggle",
    "TSHighlightCapturesUnderCursor",
    "TSNodeUnderCursor",
    "TSEditQuery",
  },
  config = function()
    vim.keymap.set("n", "<leader>tp", ":TSPlaygroundToggle<CR>", { desc = "Toggle Treesitter Playground" })
  end,
}
