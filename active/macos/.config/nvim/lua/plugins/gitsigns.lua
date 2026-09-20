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

    local function git(args)
      local result = vim.fn.systemlist(args)
      if vim.v.shell_error ~= 0 then
        return nil
      end
      return result
    end

    local function git_ref_exists(ref)
      local result = git({ "git", "rev-parse", "--verify", ref })
      return result ~= nil
    end

    local function resolve_primary_branch_ref()
      -- First choice: whatever origin/HEAD points to, usually origin/main or origin/master
      local origin_head = git({ "git", "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD" })
      if origin_head and origin_head[1] then
        local ref = origin_head[1]:gsub("^refs/remotes/", "")
        if ref ~= "" then
          return ref
        end
      end

      -- Fallbacks
      local candidates = {
        "origin/main",
        "origin/master",
        "main",
        "master",
      }

      for _, ref in ipairs(candidates) do
        if git_ref_exists(ref) then
          return ref
        end
      end

      return nil
    end

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

      local target = resolve_primary_branch_ref()
      if not target then
        vim.notify("No primary branch found (tried origin/main, origin/master, main, master)", vim.log.levels.WARN)
        return
      end

      gs.diffthis(target)
    end

    map("n", "<leader>ghn", gs_call("next_hunk"), vim.tbl_extend("force", opts, {
      desc = "Git next hunk",
    }))

    map("n", "<leader>ghN", gs_call("prev_hunk"), vim.tbl_extend("force", opts, {
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
  opts = {},
}
