return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  config = function()
    local ok, diffview = pcall(require, "diffview")
    if not ok then
      return
    end

    diffview.setup({})

    -- Keymaps (leader-d… for "diff")
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- Open Diffview for current changes
    map("n", "<leader>do", ":DiffviewOpen<CR>", opts)

    -- Close Diffview
    map("n", "<leader>dc", ":DiffviewClose<CR>", opts)

    -- Compare against previous commit (HEAD~1)
    map("n", "<leader>dp", ":DiffviewOpen HEAD~1<CR>", opts)

    -- Compare against main branch
    map("n", "<leader>dm", ":DiffviewOpen main<CR>", opts)

    -- View file history
    map("n", "<leader>dh", ":DiffviewFileHistory %<CR>", opts)

    -- View repo history (all files)
    map("n", "<leader>dH", ":DiffviewFileHistory<CR>", opts)
  end,
  opts = {},
}
