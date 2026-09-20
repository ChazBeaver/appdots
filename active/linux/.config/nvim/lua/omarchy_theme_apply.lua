local M = {}

local uv = vim.uv or vim.loop
local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
local last_mtime = 0

local function mtime(path)
  local st = uv.fs_stat(path)
  return st and st.mtime and st.mtime.sec or 0
end

local function parse_opts()
  local ok, spec = pcall(dofile, theme_file)
  if not ok or type(spec) ~= "table" then
    return nil, nil
  end

  for _, item in ipairs(spec) do
    if type(item) == "table" and item[1] == "LazyVim/LazyVim" and type(item.opts) == "table" then
      return item.opts.colorscheme, item.opts.background
    end
  end

  return nil, nil
end

local function apply_background(bg)
  if type(bg) ~= "string" then return end
  bg = bg:lower()
  -- Neovim only supports "dark" or "light"
  if bg == "dark" or bg == "light" then
    vim.o.background = bg
  end
end

local function apply()
  local cs, bg = parse_opts()
  apply_background(bg)

  if type(cs) == "string" and cs ~= "" then
    pcall(vim.cmd.colorscheme, cs)
  end
end

function M.setup()
  last_mtime = mtime(theme_file)

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      apply()
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    callback = function()
      local cur = mtime(theme_file)
      if cur ~= 0 and cur ~= last_mtime then
        last_mtime = cur
        apply()
      end
    end,
  })
end

return M
