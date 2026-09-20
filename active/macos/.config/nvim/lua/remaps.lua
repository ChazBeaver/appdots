-- REMAPS FILE --
-- I don't think these need to be defined again, but it won't hurt
local global = vim.g
local o = vim.o
vim.scriptencoding = "utf-8"

-- ############################################################################
--                              Main Keymaps
-- ############################################################################
 
-- IMPORTANT KEYMAPS

-- Map <leader>
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct
 
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

local function get_absolute_path()
  return vim.fn.expand("%:p")
end

local function get_file_dir()
  return vim.fn.expand("%:p:h")
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
  local filepath = vim.fn.fnamemodify(get_absolute_path(), ":p"):gsub("/$", "")
  local repo_root = get_repo_root()

  -- fallback if not in a git repo
  if not repo_root then
    return vim.fn.expand("%")
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
  return vim.fn.expand("%")
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

-- <leader>yfp → repo-relative file path
vim.keymap.set("n", "<leader>yfp", function()
  local path = get_repo_relative_path()
  vim.fn.setreg("+", path)
  print("📋 Copied repo path: " .. path)
end, { desc = "Copy repo-relative file path" })

-- <leader>yfP → full absolute file path
vim.keymap.set("n", "<leader>yfP", function()
  local path = get_absolute_path()
  vim.fn.setreg("+", path)
  print("📋 Copied full path: " .. path)
end, { desc = "Copy full file path" })

-- <leader>yfl → repo/path/file:line
vim.keymap.set("n", "<leader>yfl", function()
  local path = get_repo_relative_path()
  local line = vim.fn.line(".")
  local result = path .. ":" .. line

  vim.fn.setreg("+", result)
  print("📋 Copied: " .. result)
end, { desc = "Copy repo file path with line number" })

-- <leader>yfn → filename only
vim.keymap.set("n", "<leader>yfn", function()
  local name = vim.fn.expand("%:t")
  vim.fn.setreg("+", name)
  print("📋 Copied: " .. name)
end, { desc = "Copy file name" })

-- <leader>yfd → repo-relative directory
vim.keymap.set("n", "<leader>yfd", function()
  local dir = get_repo_relative_dir()
  vim.fn.setreg("+", dir)
  print("📋 Copied dir: " .. dir)
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
 
-- Switch back to the previous buffer you were just on (without using Harpoon)
vim.keymap.set("n", "<leader><Tab>", "<C-^>",
{ desc = "Switch to previous buffer" })
 
-- Source ~/.zshrc file 
vim.keymap.set("n", "<leader>fz", function()
  vim.cmd("!source ~/.zshrc")
end, { desc = "Source ~/.zshrc", silent = true })

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

-- -- Show highlight group type under cursor
-- vim.keymap.set("n", "<leader>pt", function()
--   vim.cmd('echo synIDattr(synID(line("."), col("."), 1), "name")')
-- end, { desc = "Show highlight group type under cursor" })

-- Show highlight group type under cursor
vim.keymap.set("n", "<leader>pt", function()
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")
  local id = vim.fn.synID(line, col, 1)
  local trans_id = vim.fn.synIDtrans(id)

  local name     = vim.fn.synIDattr(id, "name")
  local trans    = vim.fn.synIDattr(trans_id, "name")
  local hl       = vim.fn.synIDattr(trans_id, "fg#")

  if name == "" then
    vim.notify("No syntax group found under cursor.", vim.log.levels.WARN)
    return
  end

  vim.notify("Group: " .. name .. "\nTrans: " .. trans .. "\nFG: " .. hl, vim.log.levels.INFO)
end, { desc = "Show highlight group under cursor" })


-- ############################################################################
--                         Begin of markdown section
-- ############################################################################
 
 
-- ############################################################################
--                         Begin of github section
-- ############################################################################

-- Escape VimDiff when in VimDiff by using <Esc>
vim.keymap.set("n", "<Esc>", function()
  if vim.wo.diff then
    vim.cmd("diffoff")
    vim.cmd("only")
  end
end, { desc = "Exit diff mode cleanly" })


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
