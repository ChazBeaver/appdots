-- Markdown editing without an LSP: list continuation, task toggles,
-- inline emphasis, heading navigation and links (treesitter-based).
return {
  "tadmccorkle/markdown.nvim",
  ft = { "markdown" },
  opts = {
    on_attach = function(bufnr)
      local list = require("markdown.list")
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      -- o/O continue the list item under the cursor, including "- [ ]".
      -- Off a list item the plugin inserts nothing, so fall back to plain o/O.
      local function open_line(insert, key)
        return function()
          if not insert() then
            vim.api.nvim_feedkeys(vim.v.count1 .. key, "ni", false)
          end
        end
      end
      map("n", "o", open_line(list.insert_list_item_below, "o"), "Open line, continuing a list")
      map("n", "O", open_line(list.insert_list_item_above, "O"), "Open line above, continuing a list")

      map("n", "<leader>x", "<Cmd>MDTaskToggle<CR>", "Toggle markdown task")
      map("x", "<leader>x", ":MDTaskToggle<CR>", "Toggle markdown tasks")
    end,
  },
}
