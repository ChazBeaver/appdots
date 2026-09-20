return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  event = "VeryLazy",
  config = function()
    local ok, neogit = pcall(require, "neogit")
    if not ok then
      return
    end

    neogit.setup({
      disable_context_highlighting = true,

      popup = {
        kind = "floating",
      },

      commit_view = {
        kind = "floating",
      },
    })

    -- ============================================================
    -- Helpers
    -- ============================================================
    local function git_root_for_path(path)
      if not path or path == "" then
        return nil
      end

      local dir = vim.fn.fnamemodify(path, ":h")
      local result = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })

      if vim.v.shell_error ~= 0 or not result[1] or result[1] == "" then
        return nil
      end

      return result[1]
    end

    local function current_file_path()
      local path = vim.api.nvim_buf_get_name(0)
      if not path or path == "" then
        return nil
      end
      return vim.fn.fnamemodify(path, ":p")
    end

    local function ensure_file_saved()
      if vim.bo.modified then
        vim.cmd("write")
      end
    end

    local function resolve_git_root()
      local filepath = current_file_path()
      local root = filepath and git_root_for_path(filepath)

      if root then
        return root
      end

      local cwd = vim.fn.getcwd()
      local result = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })

      if vim.v.shell_error ~= 0 or not result[1] or result[1] == "" then
        return nil
      end

      return result[1]
    end

    local function stage_current_file()
      local filepath = current_file_path()
      if not filepath then
        vim.notify("No current file to stage", vim.log.levels.WARN)
        return
      end

      ensure_file_saved()

      local root = git_root_for_path(filepath)
      if not root then
        vim.notify("Current file is not inside a Git repository", vim.log.levels.ERROR)
        return
      end

      vim.fn.system({ "git", "-C", root, "add", filepath })

      if vim.v.shell_error ~= 0 then
        vim.notify("git add failed for current file", vim.log.levels.ERROR)
        return
      end

      vim.notify("Staged current file", vim.log.levels.INFO)
    end

    local function stage_all_files()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      vim.cmd("wall")
      vim.fn.system({ "git", "-C", root, "add", "-A" })

      if vim.v.shell_error ~= 0 then
        vim.notify("git add -A failed", vim.log.levels.ERROR)
        return
      end

      vim.notify("Staged all files", vim.log.levels.INFO)
    end

    local function quick_push_origin_head()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      vim.notify("Pushing HEAD to origin...", vim.log.levels.INFO)
      vim.fn.system({ "git", "-C", root, "push", "origin", "HEAD" })

      if vim.v.shell_error ~= 0 then
        vim.notify("git push origin HEAD failed", vim.log.levels.ERROR)
        return
      end

      vim.notify("Pushed HEAD to origin", vim.log.levels.INFO)
    end

    -- ============================================================
    -- Telescope-powered merge helpers
    -- ============================================================
    local function git_current_branch(root)
      local result = vim.fn.systemlist({ "git", "-C", root, "branch", "--show-current" })
      if vim.v.shell_error ~= 0 or not result[1] or result[1] == "" then
        return nil
      end
      return vim.trim(result[1])
    end

    local function git_local_branches(root)
      local result = vim.fn.systemlist({
        "git",
        "-C",
        root,
        "for-each-ref",
        "--format=%(refname:short)",
        "refs/heads/",
      })

      if vim.v.shell_error ~= 0 then
        return {}
      end

      local branches = {}
      for _, branch in ipairs(result) do
        branch = vim.trim(branch)
        if branch ~= "" then
          table.insert(branches, branch)
        end
      end

      return branches
    end

    local function telescope_pick_branch(opts, on_select)
      opts = opts or {}

      local ok_picker, pickers = pcall(require, "telescope.pickers")
      local ok_finders, finders = pcall(require, "telescope.finders")
      local ok_conf, conf = pcall(require, "telescope.config")
      local ok_actions, actions = pcall(require, "telescope.actions")
      local ok_action_state, action_state = pcall(require, "telescope.actions.state")

      if not (ok_picker and ok_finders and ok_conf and ok_actions and ok_action_state) then
        vim.notify("Telescope is not available", vim.log.levels.ERROR)
        return
      end

      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      local branches = git_local_branches(root)
      if vim.tbl_isempty(branches) then
        vim.notify("No local git branches found", vim.log.levels.WARN)
        return
      end

      if opts.exclude and opts.exclude ~= "" then
        branches = vim.tbl_filter(function(branch)
          return branch ~= opts.exclude
        end, branches)
      end

      if vim.tbl_isempty(branches) then
        vim.notify("No valid branches available to select", vim.log.levels.WARN)
        return
      end

      pickers.new({}, {
        prompt_title = opts.prompt_title or "Select Git Branch",
        finder = finders.new_table({
          results = branches,
        }),
        sorter = conf.values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            if not selection then
              return
            end

            local branch = selection[1]
            if not branch or branch == "" then
              return
            end

            on_select(branch, root)
          end)

          return true
        end,
      }):find()
    end

    local function merge_two_selected_branches()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      local current = git_current_branch(root)

      telescope_pick_branch({
        prompt_title = current and ("Merge FROM branch (current: " .. current .. ")") or "Merge FROM branch",
      }, function(source_branch, repo_root)
        telescope_pick_branch({
          prompt_title = "Merge INTO branch",
          exclude = source_branch,
        }, function(target_branch, repo_root_2)
          vim.notify("Switching to " .. target_branch .. "...", vim.log.levels.INFO)
          vim.fn.system({ "git", "-C", repo_root_2, "switch", target_branch })

          if vim.v.shell_error ~= 0 then
            vim.notify("Failed to switch to " .. target_branch, vim.log.levels.ERROR)
            return
          end

          vim.notify("Merging " .. source_branch .. " into " .. target_branch .. "...", vim.log.levels.INFO)
          vim.fn.system({ "git", "-C", repo_root_2, "merge", "--no-ff", source_branch })

          if vim.v.shell_error ~= 0 then
            vim.notify("Merge failed or has conflicts; open Neogit to resolve", vim.log.levels.WARN)
            vim.cmd("Neogit")
            return
          end

          vim.notify("Merged " .. source_branch .. " into " .. target_branch, vim.log.levels.INFO)
        end)
      end)
    end

    -- ============================================================
    -- Floating preview helpers
    -- ============================================================
    local function open_centered_float(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].bufhidden = "wipe"
      vim.bo[buf].modifiable = true

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines or {})
      vim.bo[buf].modifiable = false

      if opts.filetype then
        vim.bo[buf].filetype = opts.filetype
      end

      local width = opts.width or math.floor(vim.o.columns * 0.85)
      local height = opts.height or math.floor(vim.o.lines * 0.80)
      local col = math.floor((vim.o.columns - width) / 2)
      local row = math.floor((vim.o.lines - height) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = opts.title or " Preview ",
        title_pos = "center",
      })

      vim.wo[win].wrap = opts.wrap or false
      vim.wo[win].cursorline = true

      local function close_float()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end

      vim.keymap.set("n", "q", close_float, {
        buffer = buf,
        noremap = true,
        silent = true,
        nowait = true,
        desc = "Close floating window",
      })

      vim.keymap.set("n", "<Esc>", close_float, {
        buffer = buf,
        noremap = true,
        silent = true,
        nowait = true,
        desc = "Close floating window",
      })

      return buf, win
    end

    -- ============================================================
    -- Floating preview from Neogit status
    -- ============================================================
    local function find_neogit_section(bufnr, row)
      for lnum = row, 1, -1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
        if line:match("Staged changes") then
          return "staged"
        end
        if line:match("Unstaged changes") then
          return "unstaged"
        end
      end
      return nil
    end

    local function extract_neogit_filepath(line)
      local patterns = {
        "^%s*[>v]?%s*modified%s+(.+)$",
        "^%s*[>v]?%s*new file%s+(.+)$",
        "^%s*[>v]?%s*deleted%s+(.+)$",
        "^%s*[>v]?%s*renamed%s+(.+)$",
        "^%s*[>v]?%s*copied%s+(.+)$",
        "^%s*[>v]?%s*both modified%s+(.+)$",
        "^%s*[>v]?%s*added%s+(.+)$",
        "^%s*[>v]?%s*unmerged%s+(.+)$",
      }

      for _, pat in ipairs(patterns) do
        local path = line:match(pat)
        if path and path ~= "" then
          return vim.trim(path)
        end
      end

      return nil
    end

    local function open_file_from_neogit_line()
      local line = vim.api.nvim_get_current_line()
      local filepath = extract_neogit_filepath(line)
      if not filepath then
        vim.notify("Cursor is not on a changed file line", vim.log.levels.WARN)
        return
      end

      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      local fullpath = filepath
      if not filepath:match("^/") then
        fullpath = root .. "/" .. filepath
      end

      vim.cmd("edit " .. vim.fn.fnameescape(fullpath))
    end

    local function open_floating_git_preview()
      local bufnr = vim.api.nvim_get_current_buf()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local row = cursor[1]
      local line = vim.api.nvim_get_current_line()

      local filepath = extract_neogit_filepath(line)
      if not filepath then
        vim.notify("Cursor is not on a changed file line", vim.log.levels.WARN)
        return
      end

      local section = find_neogit_section(bufnr, row)
      local cmd

      if line:match("^%s*[>v]?%s*unmerged%s+") then
        cmd = { "git", "--no-pager", "diff", "--", filepath }
      elseif section == "staged" then
        cmd = { "git", "--no-pager", "diff", "--cached", "--", filepath }
      else
        cmd = { "git", "--no-pager", "diff", "--", filepath }
      end

      local output = vim.fn.systemlist(cmd)
      if vim.v.shell_error ~= 0 then
        vim.notify("git diff failed for: " .. filepath, vim.log.levels.ERROR)
        return
      end

      if not output or vim.tbl_isempty(output) then
        output = { "No diff output for " .. filepath }
      end

      local header = {
        "File: " .. filepath,
        "Section: " .. (section or "unmerged"),
        "Command: " .. table.concat(cmd, " "),
        string.rep("─", 80),
      }

      open_centered_float({
        title = " Neogit Preview ",
        filetype = "diff",
        lines = vim.list_extend(header, output),
        width = math.floor(vim.o.columns * 0.85),
        height = math.floor(vim.o.lines * 0.80),
        wrap = false,
      })
    end

    local function open_git_status_short_float()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      local output = vim.fn.systemlist({ "git", "-C", root, "status", "--short" })
      if vim.v.shell_error ~= 0 then
        vim.notify("git status --short failed", vim.log.levels.ERROR)
        return
      end

      if not output or vim.tbl_isempty(output) then
        output = { "Working tree clean" }
      end

      open_centered_float({
        title = " git status --short ",
        lines = output,
        width = math.floor(vim.o.columns * 0.60),
        height = math.min(#output + 2, math.floor(vim.o.lines * 0.60)),
        wrap = false,
      })
    end

    local function open_git_status_long_float()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      local output = vim.fn.systemlist({ "git", "-C", root, "status" })
      if vim.v.shell_error ~= 0 then
        vim.notify("git status failed", vim.log.levels.ERROR)
        return
      end

      if not output or vim.tbl_isempty(output) then
        output = { "No output from git status" }
      end

      open_centered_float({
        title = " git status ",
        lines = output,
        width = math.floor(vim.o.columns * 0.75),
        height = math.min(#output + 2, math.floor(vim.o.lines * 0.75)),
        wrap = true,
      })
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NeogitStatus",
      callback = function(args)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end

          local buf_opts = {
            buffer = args.buf,
            noremap = true,
            silent = true,
            nowait = true,
          }

          vim.keymap.set("n", "zf", function()
            local line = vim.api.nvim_get_current_line()
            local filepath = extract_neogit_filepath(line)

            if filepath then
              open_floating_git_preview()
            else
              vim.notify("Cursor is not on a changed file line", vim.log.levels.WARN)
            end
          end, vim.tbl_extend("force", buf_opts, {
            desc = "Floating git preview",
          }))

          -- vim.keymap.set("n", "e", function()
          --   local line = vim.api.nvim_get_current_line()
          --   local filepath = extract_neogit_filepath(line)
          --
          --   if filepath then
          --     open_file_from_neogit_line()
          --   else
          --     vim.notify("Cursor is not on a changed file line", vim.log.levels.WARN)
          --   end
          -- end, vim.tbl_extend("force", buf_opts, {
          --   desc = "Edit file from Neogit",
          -- }))
        end)
      end,
    })

    -- ============================================================
    -- Global keymaps
    -- ============================================================
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    map("n", "<leader>ga", "<cmd>Neogit<CR>", vim.tbl_extend("force", opts, {
      desc = "Open Neogit",
    }))

    map("n", "<leader>gC", "<cmd>Neogit commit<CR>", vim.tbl_extend("force", opts, {
      desc = "Neogit commit popup",
    }))

    map("n", "<leader>gL", "<cmd>Neogit log<CR>", vim.tbl_extend("force", opts, {
      desc = "Neogit log popup",
    }))

    map("n", "<leader>gl", "<cmd>Neogit pull<CR>", vim.tbl_extend("force", opts, {
      desc = "Neogit pull popup",
    }))

    map("n", "<leader>gP", "<cmd>Neogit push<CR>", vim.tbl_extend("force", opts, {
      desc = "Neogit push popup",
    }))

    map("n", "<leader>gsf", stage_current_file, vim.tbl_extend("force", opts, {
      desc = "Git stage file",
    }))

    map("n", "<leader>gsa", stage_all_files, vim.tbl_extend("force", opts, {
      desc = "Git stage all",
    }))

    map("n", "<leader>gss", open_git_status_short_float, vim.tbl_extend("force", opts, {
      desc = "Git status --short",
    }))

    map("n", "<leader>gsl", open_git_status_long_float, vim.tbl_extend("force", opts, {
      desc = "Git status",
    }))

    map("n", "<leader>gp", quick_push_origin_head, vim.tbl_extend("force", opts, {
      desc = "Git quick push origin HEAD",
    }))

    map("n", "<leader>gcm", function()
      local root = resolve_git_root()
      if not root then
        vim.notify("Could not determine Git repository root", vim.log.levels.ERROR)
        return
      end

      vim.ui.input({ prompt = "Commit message: " }, function(input)
        if not input or input == "" then
          vim.notify("Commit cancelled", vim.log.levels.INFO)
          return
        end

        vim.fn.system({ "git", "-C", root, "commit", "-m", input })

        if vim.v.shell_error ~= 0 then
          vim.notify("git commit failed", vim.log.levels.ERROR)
          return
        end

        vim.notify("Committed staged changes", vim.log.levels.INFO)
      end)
    end, vim.tbl_extend("force", opts, {
      desc = "Git quick commit staged changes",
    }))

    map("n", "<leader>gmb", merge_two_selected_branches, vim.tbl_extend("force", opts, {
      desc = "Pick target branch, then source branch, then merge",
    }))
  end,
  opts = {},
}
