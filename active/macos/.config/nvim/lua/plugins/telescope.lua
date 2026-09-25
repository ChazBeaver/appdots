return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    config = function()
      local builtin = require("telescope.builtin")

      -- Scroll the preview with Alt + vim motions (replaces the default
      -- <C-f>/<C-k> left/right and <C-u>/<C-d> up/down). Needs Ghostty's
      -- macos-option-as-alt so Option sends Alt instead of a symbol.
      require("telescope").setup({
        defaults = {
          -- The "deep" pickers pass --hidden --no-ignore, so keep .git
          -- internals out of every result list.
          file_ignore_patterns = { "^%.git/", "/%.git/" },
          mappings = {
            i = {
              ["<M-h>"] = "preview_scrolling_left",
              ["<M-j>"] = "preview_scrolling_down",
              ["<M-k>"] = "preview_scrolling_up",
              ["<M-l>"] = "preview_scrolling_right",
            },
            n = {
              ["<M-h>"] = "preview_scrolling_left",
              ["<M-j>"] = "preview_scrolling_down",
              ["<M-k>"] = "preview_scrolling_up",
              ["<M-l>"] = "preview_scrolling_right",
            },
          },
        },
      })

      -- =========================
      -- Selection / preview highlights
      -- =========================
      -- The afternoon theme's TelescopeSelection (#1D2124) and
      -- TelescopePreviewLine (#171A1D) are too close to the panel
      -- background (#0D0F11) to spot. Lift both to the palette's bg_3 and
      -- mark the search text in the preview with the theme's gold.
      -- Re-applied on ColorScheme because loading a theme resets highlights.
      local function set_telescope_highlights()
        vim.api.nvim_set_hl(0, "TelescopeSelection", { bg = "#32363A", bold = true })
        vim.api.nvim_set_hl(0, "TelescopePreviewLine", { bg = "#32363A", bold = true })
        vim.api.nvim_set_hl(0, "TelescopePreviewMatch", { fg = "#C89A56", bold = true, underline = true })
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("TelescopeHighlights", { clear = true }),
        callback = set_telescope_highlights,
      })
      set_telescope_highlights()

      -- Grep previewer that marks the search text. Telescope only
      -- highlights the whole matched line, so the hit itself is not
      -- visible on long lines. Scroll the preview with <C-f> (left),
      -- <C-k> (right), <C-u> (up) and <C-d> (down).
      --
      -- Built from the configured grep previewer (vim_buffer_vimgrep), not
      -- previewers.vimgrep, which is the older terminal previewer and has
      -- no horizontal scroll or window state. Hooks preview_fn (the method
      -- Previewer:preview calls), since define_preview is already captured
      -- in a closure at construction. The window id is taken from status.
      local function marked_grep_previewer(opts, pattern)
        local previewer = require("telescope.config").values.grep_previewer(opts)
        local preview_fn = previewer.preview_fn
        previewer.preview_fn = function(self, entry, status)
          preview_fn(self, entry, status)
          local win = status.preview_win
            or (status.layout and status.layout.preview and status.layout.preview.winid)
          vim.schedule(function()
            if win and vim.api.nvim_win_is_valid(win) then
              -- Fixed id so re-adding on every entry is a no-op instead of a pile-up.
              pcall(vim.fn.matchadd, "TelescopePreviewMatch", pattern, 20, 4242, { window = win })
            end
          end)
        end
        return previewer
      end

      -- grep_string with the literal search text marked in the preview.
      -- Case-sensitivity mirrors rg: smart-case unless opts.case_sensitive.
      -- Shared by the deep pickers; the glob stops rg walking .git at all.
      local deep_args = { "--hidden", "--no-ignore", "--glob", "!.git/" }

      local function grep_string_marked(opts)
        opts = opts or {}
        local search = opts.search or vim.fn.expand("<cword>")
        if search == "" then
          return
        end
        opts.search = search

        local case = (opts.case_sensitive or search:find("%u")) and [[\C]] or [[\c]]
        local pattern = [[\V]] .. case .. vim.fn.escape(search, "\\")
        opts.previewer = marked_grep_previewer(opts, pattern)

        require("telescope.builtin").grep_string(opts)
      end


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
            return deep_args
          end,
        })
      end, { desc = "Deep search (includes hidden)" })

      vim.keymap.set("n", "<leader>ss", function()
        grep_string_marked({
          search = vim.fn.input("Grep > "),
          additional_args = function()
            return deep_args
          end,
        })
      end, { desc = "Search for input string (deep search)" })

      vim.keymap.set("n", "<leader>sw", function()
        grep_string_marked({
          additional_args = function()
            return deep_args
          end,
        })
      end, { desc = "Search word under cursor (deep search)" })

      -- <leader>sr: search a literal string, browse the matches in Telescope,
      -- then replace it file by file with a y/n/a/q prompt on every match.
      --
      -- Both strings are taken literally, so paths like ~/.config/test/path
      -- or replacements like ~/new/special-path/whatever need no escaping.
      --
      -- In the picker:  <CR> replaces in every listed file,
      --                 <Tab> marks specific results first, then <CR>.
      -- At each match:  y = replace, n = skip, a = all in this file,
      --                 q = skip rest of this file, <C-c> = abort everything.
      --
      -- Files are visited in a Lua loop instead of :cfdo so that no
      -- "(1 of N)", "N substitutions" or "written" messages pile up and
      -- force a "Press ENTER" prompt between files.
      vim.keymap.set("n", "<leader>sr", function()
        local search = vim.fn.input("Replace > ")
        if search == "" then
          return
        end

        local actions = require("telescope.actions")

        grep_string_marked({
          prompt_title = "Replace '" .. search .. "'  (<CR> all, <Tab> pick)",
          search = search,
          case_sensitive = true,
          additional_args = function()
            return vim.list_extend({ "--case-sensitive" }, deep_args)
          end,
          attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
              -- Tab-selected entries if any, otherwise every listed result.
              actions.smart_send_to_qflist(prompt_bufnr)

              -- Unique files, in result order.
              local files, seen = {}, {}
              for _, item in ipairs(vim.fn.getqflist()) do
                local name = vim.fn.bufname(item.bufnr)
                if name ~= "" and not seen[name] then
                  seen[name] = true
                  table.insert(files, name)
                end
              end
              if vim.tbl_isempty(files) then
                vim.notify("No matches to replace", vim.log.levels.WARN)
                return
              end

              local replacement = vim.fn.input("Replace '" .. search .. "' with > ")
              if replacement == "" then
                vim.notify("Replace cancelled", vim.log.levels.INFO)
                return
              end

              -- Pick a delimiter that appears in neither string so the
              -- prompt shows the replacement without escaped slashes.
              local delim = "/"
              for d in ("/#@!,;"):gmatch(".") do
                if not search:find(d, 1, true) and not replacement:find(d, 1, true) then
                  delim = d
                  break
                end
              end

              -- \V = very nomagic (only \ is special), \C = match case,
              -- which mirrors the --fixed-strings --case-sensitive rg search.
              local pattern = [[\V\C]] .. vim.fn.escape(search, "\\" .. delim)
              local subst = vim.fn.escape(replacement, "\\&~" .. delim)
              local cmd = "%s" .. delim .. pattern .. delim .. subst .. delim .. "gce"

              -- Silence "N substitutions on M lines" so nothing but the
              -- confirm prompt reaches the command line.
              local report = vim.o.report
              vim.o.report = 2147483647
              local ok, err = pcall(function()
                for _, file in ipairs(files) do
                  vim.cmd("silent edit " .. vim.fn.fnameescape(file))
                  vim.cmd(cmd)
                  vim.cmd("silent update")
                end
              end)
              vim.o.report = report

              if not ok then
                if tostring(err):find("Keyboard interrupt", 1, true) then
                  vim.notify("Replace aborted; current buffer left unsaved", vim.log.levels.WARN)
                else
                  vim.notify(tostring(err), vim.log.levels.ERROR)
                end
                return
              end
              vim.notify("Replace finished in " .. #files .. " file(s)", vim.log.levels.INFO)
            end)
            return true
          end,
        })
      end, { desc = "Search literal string and replace with confirmation" })

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
