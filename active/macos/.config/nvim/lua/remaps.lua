-- REMAPS FILE --
-- <leader> is set in init.lua before lazy loads; do not set it again here.

-- ############################################################################
--                              Main Keymaps
-- ############################################################################

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Focus window below" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Focus window above" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Focus window right" })

-- Return Current File Directory
vim.keymap.set("n", "<leader>e", vim.cmd.Ex,
  { desc = "Return to File Directory" })
 
-- Return to Working Directory
vim.keymap.set("n", "<leader>ER", [[:Explore .<CR>]],
  { desc = "Explore Current Working Directory" })
 
-- Explore Home Directory
vim.keymap.set("n", "<leader>EH", [[:Explore ~/.<CR>]],
{ desc = "Explore Home Root Directory" })

-- ============================================================
-- PATH HELPERS
-- ============================================================

-- The file a <leader>yf* map is about: the node under the cursor in
-- Neo-tree, the entry under the cursor in netrw, otherwise the buffer's
-- own file. Returns "" when there is nothing to point at.
local function get_absolute_path()
  local path = ""
  if vim.bo.filetype == "neo-tree" then
    local ok, manager = pcall(require, "neo-tree.sources.manager")
    local state = ok and manager.get_state_for_window() or nil
    local node = state and state.tree and state.tree:get_node() or nil
    path = node and node.path or ""
  elseif vim.bo.filetype == "netrw" then
    local dir = vim.b.netrw_curdir
    local ok, name = pcall(vim.fn["netrw#Call"], "NetrwGetWord")
    if dir and ok and type(name) == "string" and name ~= "" then
      path = dir .. "/" .. name
    end
  else
    path = vim.fn.expand("%:p")
  end
  if path == "" then
    return ""
  end
  return (vim.fn.fnamemodify(path, ":p"):gsub("/$", ""))
end

local function get_file_dir()
  local path = get_absolute_path()
  if path == "" then
    return ""
  end
  return vim.fn.fnamemodify(path, ":h")
end

local function get_repo_root()
  local file_dir = get_file_dir()

  if file_dir == "" then
    return nil
  end

  local cmd = "git -C " .. vim.fn.shellescape(file_dir) .. " rev-parse --show-toplevel"
  local result = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 or not result or not result[1] or result[1] == "" then
    return nil
  end

  return vim.fn.fnamemodify(result[1], ":p"):gsub("/$", "")
end

local function get_repo_relative_path()
  local filepath = get_absolute_path()
  local repo_root = get_repo_root()

  -- fallback if not in a git repo
  if not repo_root then
    return filepath
  end

  -- repo name, e.g. "theme-engine"
  local repo_name = vim.fn.fnamemodify(repo_root, ":t")

  -- if file lives under repo root, strip prefix safely
  if filepath:sub(1, #repo_root) == repo_root then
    local relative = filepath:sub(#repo_root + 2) -- skip trailing "/"

    if relative ~= "" then
      return repo_name .. "/" .. relative
    else
      return repo_name
    end
  end

  -- fallback
  return filepath
end

local function get_repo_relative_dir()
  local path = get_repo_relative_path()
  local dir = vim.fn.fnamemodify(path, ":h")

  if dir == "." then
    return ""
  end

  if dir ~= "" and not dir:match("/$") then
    dir = dir .. "/"
  end

  return dir
end

-- ============================================================
-- KEYMAPS
-- ============================================================

local function yank_path(label, value)
  if get_absolute_path() == "" then
    vim.notify("No file under cursor to copy", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", value)
  vim.notify("📋 Copied " .. label .. ": " .. value, vim.log.levels.INFO)
end

-- <leader>yfp → repo-relative file path
vim.keymap.set("n", "<leader>yfp", function()
  yank_path("repo path", get_repo_relative_path())
end, { desc = "Copy repo-relative file path" })

-- <leader>yfP → full absolute file path
vim.keymap.set("n", "<leader>yfP", function()
  yank_path("full path", get_absolute_path())
end, { desc = "Copy full file path" })

-- <leader>yfl → repo/path/file:line (in an explorer the line is the
-- cursor row, so this only makes sense inside a file)
vim.keymap.set("n", "<leader>yfl", function()
  yank_path("path:line", get_repo_relative_path() .. ":" .. vim.fn.line("."))
end, { desc = "Copy repo file path with line number" })

-- <leader>yfn → filename only
vim.keymap.set("n", "<leader>yfn", function()
  yank_path("file name", vim.fn.fnamemodify(get_absolute_path(), ":t"))
end, { desc = "Copy file name" })

-- <leader>yfd → repo-relative directory
vim.keymap.set("n", "<leader>yfd", function()
  yank_path("dir", get_repo_relative_dir())
end, { desc = "Copy repo-relative directory path" })
 
-- ############################################################################
--                              Fun Keymaps
-- ############################################################################

-- Theme Selector
vim.keymap.set("n", "<leader>tt", function()
  require("theme_manager").pick_theme()
end, { desc = "Theme picker" })
 
-- Launch Lazy Menu
vim.keymap.set("n", "<leader>l", vim.cmd.Lazy,
  { desc = "Launch Lazy Menu" })
 
-- Clear Highlight Search
vim.keymap.set("n", "<leader>nh", vim.cmd.noh, -- short for nohlsearch
  { desc = "[P] No Highlight - Clear Highlight Search" })
 
-- Toggle Relative Numbers
vim.keymap.set("n", "<leader>rnu", function()
  vim.cmd("set rnu!")
end, { desc = "[P] Toggle Relative Line Numbers" })

-- Delete All Marks
vim.keymap.set("n", "<leader>mD", [[:delmarks!<CR>]],
{ desc = "Delete All Marks" })

-- Edit Highlighted Lines
vim.keymap.set("v", "<leader>n", [[:norm ]],
{ desc = "Edit Highlighted Lines with `:norm` " })

-- Copy the entire file to clipboard
vim.keymap.set("n", "<leader>ya", [[ggVG"+y]],
  { desc = "Copy entire file to clipboard" })

-- Highlight the entire file
vim.keymap.set("n", "<leader>va", [[ggVG]],
  { desc = "Highlight the entire file" })

-- Copy the current date to clipboard (yyyy-mm-dd)
function CopyCurrentDate()
  local date = os.date("%Y-%m-%d")
  vim.fn.setreg("+", date)  -- Copy to system clipboard
  print("Copied to clipboard: " .. date)
end
-- Keybindings
vim.keymap.set("n", "<leader>cd", CopyCurrentDate, { desc = "Copy current date (YYYY-MM-DD)" })
 
-- When searching for stuff, search results show in the middle #NOTE
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
 
-- Switch back to the previous buffer you were just on
vim.keymap.set("n", "<leader><Tab>", "<C-^>",
{ desc = "Switch to previous buffer" })
 
-- Make file exacutable
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.keymap.set("n", "<leader>sh", function()
      local filename = vim.fn.getline("."):match("%S+$")
      local dir = vim.b.netrw_curdir
      if filename and dir then
        local fullpath = dir .. "/" .. filename
        local ok = os.execute("chmod +x " .. vim.fn.shellescape(fullpath))
        if ok == 0 then
          print("Made executable: " .. fullpath)
        else
          print("Failed to chmod: " .. fullpath)
        end
      else
        print("Could not determine file path")
      end
    end, { buffer = true, desc = "Make file executable" })
  end,
})


-- ############################################################################
--                         Begin of markdown section
-- ############################################################################
 
 
-- ############################################################################
--                         Begin of github section
-- ############################################################################

-- q (or <Esc>) closes a diff opened by gitsigns diffthis or `nvim -d`, like
-- q closes Neogit buffers and the floating previews. The maps are
-- buffer-local and exist only while the buffer is shown in diff mode, so
-- q still records macros everywhere else. Diffview manages its own tab and
-- keys, so its diff windows are left alone.
local function in_diffview()
  if vim.t.diffview_view_initialized then
    return true
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.startswith(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)), "diffview://") then
      return true
    end
  end
  return false
end

local function close_diff()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff then
      local buf = vim.api.nvim_win_get_buf(win)
      local scratch = vim.bo[buf].buftype ~= ""
        or vim.startswith(vim.api.nvim_buf_get_name(buf), "gitsigns://")
      if scratch and #vim.api.nvim_tabpage_list_wins(0) > 1 then
        vim.api.nvim_win_close(win, true)
      end
    end
  end
  vim.cmd("diffoff!")
end

vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "diff",
  callback = function()
    if vim.wo.diff and not in_diffview() then
      vim.keymap.set("n", "q", close_diff, { buffer = true, nowait = true, desc = "Close diff" })
      vim.keymap.set("n", "<Esc>", close_diff, { buffer = true, nowait = true, desc = "Close diff" })
    else
      pcall(vim.keymap.del, "n", "q", { buffer = true })
      pcall(vim.keymap.del, "n", "<Esc>", { buffer = true })
    end
  end,
})


-- -- Function to get the GitHub URL of the current file
-- local function get_github_url_of_current_file()
--   local file_path = vim.fn.expand("%:p")
--   if file_path == "" then
--     vim.notify("No file is currently open", vim.log.levels.WARN)
--     return nil
--   end
--
--   local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
--   if not git_root or git_root == "" then
--     vim.notify("Could not determine the root directory for the GitHub repository", vim.log.levels.WARN)
--     return nil
--   end
--
--   local origin_url = vim.fn.systemlist("git config --get remote.origin.url")[1]
--   if not origin_url or origin_url == "" then
--     vim.notify("Could not determine the origin URL for the GitHub repository", vim.log.levels.WARN)
--     return nil
--   end
--
--   local branch_name = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
--   if not branch_name or branch_name == "" then
--     vim.notify("Could not determine the current branch name", vim.log.levels.WARN)
--     return nil
--   end
--
--   local repo_url = origin_url:gsub(git@github.com[^:]*:, https://github.com/):gsub("%.git$", "")
--   local relative_path = file_path:sub(#git_root + 2)
--   return repo_url .. "/blob/" .. branch_name .. "/" .. relative_path
-- end
--
-- -- Open current file's GitHub repo link lamw25wmal
-- vim.keymap.set("n", "<leader>fG", function()
--   local github_url = get_github_url_of_current_file()
--   if github_url then
--     local command = "open " .. vim.fn.shellescape(github_url)
--     vim.fn.system(command)
--     print("Opened GitHub link: " .. github_url)
--   end
-- end, { desc = "[P]Open current file's GitHub repo link" })
--
-- -- Keymap to copy current file's GitHub URL to clipboard
-- vim.keymap.set({ "n", "v", "i" }, "<M-C>", function()
--   local github_url = get_github_url_of_current_file()
--   if github_url then
--     vim.fn.setreg("+", github_url)
--     vim.notify(github_url, vim.log.levels.INFO)
--     vim.notify("GitHub URL copied to clipboard", vim.log.levels.INFO)
--   end
-- end, { desc = "[P]Copy GitHub URL of file to clipboard" })
--
-- -- Function to copy file path to clipboard
-- local function copy_filepath_to_clipboard()
--   local filePath = vim.fn.expand("%:~") -- Gets the file path relative to the home directory
--   vim.fn.setreg("+", filePath) -- Copy the file path to the clipboard register
--   vim.notify(filePath, vim.log.levels.INFO)
--   vim.notify("Path copied to clipboard: ", vim.log.levels.INFO)
-- end
-- -- Keymaps for copying file path to clipboard
-- -- vim.keymap.set("n", "<leader>fp", copy_filepath_to_clipboard, { desc = "[P]Copy file path to clipboard" })
-- -- I couldn't use <M-p> because its used for previous reference
-- vim.keymap.set({ "n", "v", "i" }, "<M-c>", copy_filepath_to_clipboard, { desc = "[P]Copy file path to clipboard" })
--
-- -- Keymap to create a GitHub repository
-- -- It uses the github CLI, which in macOS is installed with:
-- -- brew install gh
-- vim.keymap.set("n", "<leader>gC", function()
--   -- Check if GitHub CLI is installed
--   local gh_installed = vim.fn.system("command -v gh")
--   if gh_installed == "" then
--     print("GitHub CLI is not installed. Please install it using 'brew install gh'.")
--     return
--   end
--   -- Get the current working directory and extract the repository name
--   local cwd = vim.fn.getcwd()
--   local repo_name = vim.fn.fnamemodify(cwd, ":t")
--   if repo_name == "" then
--     print("Failed to extract repository name from the current directory.")
--     return
--   end
--   -- Display the message and ask for confirmation
--   vim.ui.select({ "yes", "no" }, {
--     prompt = 'The name of the repo will be: "' .. repo_name .. '". Continue?',
--     default = "no",
--   }, function(choice)
--     if choice ~= "yes" then
--       print("Operation canceled.")
--       return
--     end
--     -- Check if the repository already exists on GitHub
--     local check_repo_command =
--       string.format("gh repo view %s/%s", vim.fn.system("gh api user --jq '.login'"):gsub("%s+", ""), repo_name)
--     local check_repo_result = vim.fn.systemlist(check_repo_command)
--     if not string.find(table.concat(check_repo_result), "Could not resolve to a Repository") then
--       print("Repository '" .. repo_name .. "' already exists on GitHub.")
--       return
--     end
--     -- Prompt for repository type
--     vim.ui.select({ "private", "public" }, {
--       prompt = "Select the repository type:",
--       default = "private",
--     }, function(repo_type)
--       if not repo_type then
--         print("Operation canceled.")
--         return
--       end
--       -- Set the repository type flag
--       local repo_type_flag = repo_type == "private" and "--private" or "--public"
--       -- Initialize the git repository and create the GitHub repository
--       local init_command = string.format("cd %s && git init", vim.fn.shellescape(cwd))
--       vim.fn.system(init_command)
--       local create_command =
--         string.format("cd %s && gh repo create %s %s --source=.", vim.fn.shellescape(cwd), repo_name, repo_type_flag)
--       local create_result = vim.fn.system(create_command)
--       -- Print the result of the repository creation command
--       if string.find(create_result, https://github.com) then
--         print("Repository '" .. repo_name .. "' created successfully.")
--       else
--         print("Failed to create the repository: " .. create_result)
--       end
--     end)
--   end)
-- end, { desc = "[P]Create GitHub repository" })
