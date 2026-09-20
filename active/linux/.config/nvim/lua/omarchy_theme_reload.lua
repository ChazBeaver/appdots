local M = {}

local uv = vim.uv or vim.loop
local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
local last_mtime = 0

local function get_mtime(path)
  local stat = uv.fs_stat(path)
  return stat and stat.mtime and stat.mtime.sec or 0
end

local function parse_theme()
  local ok, spec = pcall(dofile, theme_file)
  if not ok or type(spec) ~= "table" then
    return nil, nil
  end

  local colorscheme, background
  for _, item in ipairs(spec) do
    if type(item) == "table" and item[1] == "LazyVim/LazyVim" and type(item.opts) == "table" then
      colorscheme = item.opts.colorscheme
      background  = item.opts.background
      break
    end
  end

  return colorscheme, background
end

function M.check_and_apply()
  local mtime = get_mtime(theme_file)
  if mtime == 0 or mtime == last_mtime then
    return
  end
  last_mtime = mtime

  local colorscheme, background = parse_theme()
  if background and type(background) == "string" then
    vim.o.background = background
  end
  if colorscheme and type(colorscheme) == "string" then
    -- This will work if the theme plugin was installed at any point.
    -- If the plugin isn't installed yet, run :Lazy sync once (expected).
    pcall(vim.cmd.colorscheme, colorscheme)
  end
end

function M.setup()
  last_mtime = get_mtime(theme_file)

  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
    callback = function()
      -- safe, not a fast event
      M.check_and_apply()
    end,
  })
end

return M
