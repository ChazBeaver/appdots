vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "NeogitStatus",
    "NeogitCommitView",
    "NeogitLogView",
    "NeogitPopup",
    "NeogitRebaseDone",
    "NeogitRebaseTodo",
  },
  callback = function()
    vim.opt_local.cursorline = false
    vim.opt_local.winhl =
      "CursorLine:Normal,CursorLineNr:LineNr,CursorLineSign:SignColumn"
  end,
})
