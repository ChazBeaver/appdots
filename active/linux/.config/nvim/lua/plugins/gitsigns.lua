return {
  "lewis6991/gitsigns.nvim",
  event = "VeryLazy",
  config = function()
    local ok, gitsigns = pcall(require, "gitsigns")
    if not ok then
      return
    end

    gitsigns.setup({})

    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    local function gs_call(method, ...)
      local args = { ... }
      return function()
        local ok_gs, gs = pcall(require, "gitsigns")
        if not ok_gs then
          vim.notify("gitsigns not available", vim.log.levels.ERROR)
          return
        end

        local fn = gs[method]
        if type(fn) ~= "function" then
          vim.notify("gitsigns method missing: " .. method, vim.log.levels.ERROR)
          return
        end

        fn(unpack(args))
      end
    end

    local function diff_vs_primary_branch()
      local ok_gs, gs = pcall(require, "gitsigns")
      if not ok_gs then
        vim.notify("gitsigns not available", vim.log.levels.ERROR)
        return
      end

      local root = require("git_util").root()
      local target = root and require("git_util").primary_branch(root)
      if not target then
        vim.notify("No primary branch found (tried origin/main, origin/master, main, master)", vim.log.levels.WARN)
        return
      end

      gs.diffthis(target)
    end

    map("n", "]h", gs_call("nav_hunk", "next"), vim.tbl_extend("force", opts, {
      desc = "Git next hunk",
    }))

    map("n", "[h", gs_call("nav_hunk", "prev"), vim.tbl_extend("force", opts, {
      desc = "Git previous hunk",
    }))

    map("n", "<leader>ghp", gs_call("preview_hunk"), vim.tbl_extend("force", opts, {
      desc = "Git preview hunk",
    }))

    map("n", "<leader>gdf", gs_call("diffthis"), vim.tbl_extend("force", opts, {
      desc = "file vs HEAD/default",
    }))

    map("n", "<leader>gdm", diff_vs_primary_branch, vim.tbl_extend("force", opts, {
      desc = "Git diff this file vs primary branch",
    }))

    map("n", "<leader>gdp", gs_call("diffthis", "@{-1}"), vim.tbl_extend("force", opts, {
      desc = "Git diff this file vs previous checkout",
    }))

    map("n", "<leader>gB", gs_call("blame_line"), vim.tbl_extend("force", opts, {
      desc = "Git blame line",
    }))

    map("n", "<leader>ghs", gs_call("stage_hunk"), vim.tbl_extend("force", opts, {
      desc = "Git stage hunk",
    }))

    map("n", "<leader>ghr", gs_call("reset_hunk"), vim.tbl_extend("force", opts, {
      desc = "Git reset hunk",
    }))
  end,
}
