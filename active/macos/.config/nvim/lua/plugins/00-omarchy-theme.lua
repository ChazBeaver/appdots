local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

local function load_omarchy_plugins()
  local ok, spec = pcall(dofile, theme_file)
  if not ok or type(spec) ~= "table" then
    return {}
  end

  local out = {}

  for _, item in ipairs(spec) do
    if type(item) == "table" then
      local plugin = item[1]

      -- We are NOT using LazyVim; ignore this entry but keep its opts for apply step elsewhere
      if plugin ~= "LazyVim/LazyVim" then
        item.lazy = false
        item.priority = item.priority or 1000
        table.insert(out, item)
      end
    end
  end

  return out
end

return load_omarchy_plugins()
