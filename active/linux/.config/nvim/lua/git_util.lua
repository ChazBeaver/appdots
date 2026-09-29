-- Shared git helpers for remaps.lua and the plugin specs.

local M = {}

--- Run git inside `dir`. Returns the output lines, or nil when git fails.
function M.git(dir, ...)
  local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", dir }, { ... }))
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

--- Repository root containing `dir`. With no argument, tries the current
--- buffer's directory and then the working directory. nil outside a repo.
function M.root(dir)
  local candidates = {}
  if dir and dir ~= "" then
    candidates = { dir }
  else
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" then
      table.insert(candidates, vim.fn.fnamemodify(name, ":p:h"))
    end
    table.insert(candidates, vim.fn.getcwd())
  end
  for _, d in ipairs(candidates) do
    if vim.fn.isdirectory(d) == 1 then
      local out = M.git(d, "rev-parse", "--show-toplevel")
      if out and out[1] and out[1] ~= "" then
        return (out[1]:gsub("/$", ""))
      end
    end
  end
  return nil
end

--- Current branch name, or nil when HEAD is detached.
function M.current_branch(root)
  local out = M.git(root, "branch", "--show-current")
  local name = out and out[1] and vim.trim(out[1]) or ""
  return name ~= "" and name or nil
end

--- Branch names: local ones, plus remote ones when `include_remote`.
--- Remote HEAD aliases are skipped.
function M.branches(root, include_remote)
  local refs = { "refs/heads/" }
  if include_remote then
    table.insert(refs, "refs/remotes/")
  end
  local out = M.git(root, "for-each-ref", "--format=%(refname:short)", unpack(refs)) or {}
  local branches = {}
  for _, b in ipairs(out) do
    b = vim.trim(b)
    if b ~= "" and not b:match("/HEAD$") then
      table.insert(branches, b)
    end
  end
  return branches
end

--- The ref to diff against: whatever origin/HEAD points at, else the first
--- of origin/main, origin/master, main, master that exists. nil if none.
function M.primary_branch(root)
  local head = M.git(root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
  if head and head[1] then
    local ref = head[1]:gsub("^refs/remotes/", "")
    if ref ~= "" then
      return ref
    end
  end
  for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    if M.git(root, "rev-parse", "--verify", "--quiet", ref) then
      return ref
    end
  end
  return nil
end

--- Read-only centered floating window showing `opts.lines`; q and <Esc>
--- close it. Accepts title, filetype, width, height and wrap.
function M.float(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines or {})
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end

  local width = opts.width or math.floor(vim.o.columns * 0.85)
  local height = opts.height or math.floor(vim.o.lines * 0.80)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = opts.title or " Preview ",
    title_pos = "center",
  })
  vim.wo[win].wrap = opts.wrap or false
  vim.wo[win].cursorline = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true, desc = "Close floating window" })
  end

  return buf, win
end

return M
