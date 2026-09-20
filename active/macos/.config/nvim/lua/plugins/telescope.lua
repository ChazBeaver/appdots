return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    config = function()
      local builtin = require("telescope.builtin")

      -- =========================
      -- Files / navigation
      -- =========================
      vim.keymap.set("n", "<leader>ff", function()
        require("telescope.builtin").find_files({
          hidden = true,
          no_ignore = true,
        })
      end, { desc = "Find ALL files in project" })

      vim.keymap.set("n", "<leader>fa", function()
        require("telescope.builtin").find_files({
          cwd = vim.fn.expand("~"),
          hidden = true,
          no_ignore = true,
        })
      end, { desc = "Find ALL files from $HOME" })

      vim.keymap.set("n", "<leader>fo", function()
        require("telescope.builtin").find_files({
          cwd = vim.fn.expand("~/.local/share/omarchy"),
          hidden = true,
          no_ignore = true,
        })
      end, { desc = "Find Omarchy files" })

      -- vim.keymap.set("n", "<leader>fg", builtin.git_files, { desc = "Find git files" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })

      -- =========================
      -- Search
      -- =========================
      vim.keymap.set("n", "<leader>sl", function()
        builtin.live_grep({
          additional_args = function()
            return { "--hidden", "--no-ignore" }
          end,
        })
      end, { desc = "Deep search (includes hidden)" })

      vim.keymap.set("n", "<leader>ss", function()
        require("telescope.builtin").grep_string({
          search = vim.fn.input("Grep > "),
          additional_args = function()
            return { "--hidden", "--no-ignore" }
          end,
        })
      end, { desc = "Search for input string (deep search)" })

      vim.keymap.set("n", "<leader>sw", function()
        require("telescope.builtin").grep_string({
          additional_args = function()
            return { "--hidden", "--no-ignore" }
          end,
        })
      end, { desc = "Search word under cursor (deep search)" })

      vim.keymap.set("n", "<leader>sg", function()
        local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
        if not git_root or git_root == "" then
          vim.notify("Not inside a git repository", vim.log.levels.WARN)
          return
        end

        require("telescope.builtin").live_grep({
          additional_args = function()
            return { "--hidden" }
          end,
          cwd = git_root,
        })
      end, { desc = "Search git repo" })

      vim.keymap.set("n", "<leader>gfd", function()
        local filepath = vim.fn.expand("%:p")
        if filepath == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end

        local file_dir = vim.fn.fnamemodify(filepath, ":h")
        local root = vim.fn.systemlist({ "git", "-C", file_dir, "rev-parse", "--show-toplevel" })[1]
        if vim.v.shell_error ~= 0 or not root or root == "" then
          vim.notify("Current file is not in a git repository", vim.log.levels.ERROR)
          return
        end

        local rel_path = filepath:sub(#root + 2)

        -- Collect local + remote branches (skip HEAD aliases)
        local raw = vim.fn.systemlist({
          "git", "-C", root, "for-each-ref",
          "--format=%(refname:short)",
          "refs/heads/", "refs/remotes/",
        })
        local branches = {}
        for _, b in ipairs(raw) do
          b = vim.trim(b)
          if b ~= "" and not b:match("/HEAD$") then
            table.insert(branches, b)
          end
        end

        if vim.tbl_isempty(branches) then
          vim.notify("No git branches found", vim.log.levels.WARN)
          return
        end

        local pickers      = require("telescope.pickers")
        local finders      = require("telescope.finders")
        local conf         = require("telescope.config").values
        local actions      = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        pickers.new({}, {
          prompt_title = "Compare " .. rel_path .. " against branch",
          finder = finders.new_table({ results = branches }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if not selection then return end
              local branch = selection[1]

              local diff = vim.fn.systemlist({
                "git", "-C", root, "--no-pager", "diff", branch, "--", filepath,
              })
              if vim.v.shell_error ~= 0 then
                vim.notify("git diff failed for " .. branch, vim.log.levels.ERROR)
                return
              end
              if not diff or vim.tbl_isempty(diff) then
                diff = { "No differences between current file and " .. branch }
              end

              local buf = vim.api.nvim_create_buf(false, true)
              vim.bo[buf].bufhidden = "wipe"
              local header = {
                "File:   " .. rel_path,
                "Branch: " .. branch,
                "Cmd:    git diff " .. branch .. " -- " .. rel_path,
                string.rep("─", 80),
              }
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.list_extend(header, diff))
              vim.bo[buf].modifiable = false
              vim.bo[buf].filetype = "diff"

              local width  = math.floor(vim.o.columns * 0.85)
              local height = math.floor(vim.o.lines * 0.80)
              local win = vim.api.nvim_open_win(buf, true, {
                relative   = "editor",
                width      = width,
                height     = height,
                col        = math.floor((vim.o.columns - width) / 2),
                row        = math.floor((vim.o.lines - height) / 2),
                style      = "minimal",
                border     = "rounded",
                title      = " Compare against " .. branch .. " ",
                title_pos  = "center",
              })
              vim.wo[win].wrap = false
              vim.wo[win].cursorline = true

              local function close()
                if vim.api.nvim_win_is_valid(win) then
                  vim.api.nvim_win_close(win, true)
                end
              end
              vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
              vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })
            end)
            return true
          end,
        }):find()
      end, { desc = "Compare current file against a branch (Telescope)" })

      -- =========================
      -- Git
      -- =========================
      vim.keymap.set("n", "<leader>gcc", builtin.git_commits, { desc = "Git commits" })
      vim.keymap.set("n", "<leader>gb", builtin.git_branches, { desc = "Git branches" })
      vim.keymap.set("n", "<leader>gt", builtin.git_status, { desc = "Git status" })
      vim.keymap.set("n", "<leader>gfh", builtin.git_bcommits, { desc = "Git history for current file" })
      vim.keymap.set("v", "<leader>gfh", builtin.git_bcommits_range, { desc = "Git history for selected lines" })

      -- =========================
      -- Diagnostics / help
      -- =========================
      vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "Search diagnostics" })

      require("telescope").load_extension("ui-select")
    end,
  },

  {
    "nvim-telescope/telescope-ui-select.nvim",
  },
}
