local M = {}

local theme_file = vim.fn.stdpath("config") .. "/theme.txt"

local function default_theme()
  return "afternoon"
end

function M.get_saved_theme()
  if vim.fn.filereadable(theme_file) ~= 1 then
    return default_theme()
  end

  local lines = vim.fn.readfile(theme_file)
  if not lines or #lines == 0 then
    return default_theme()
  end

  local theme = vim.trim(lines[1])
  if theme == "" then
    return default_theme()
  end

  return theme
end

function M.save_theme(theme)
  vim.fn.writefile({ theme }, theme_file)
end

function M.get_installed_themes()
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if not ok then
    return {}
  end

  local themes = {}

  for plugin_name, plugin in pairs(lazy_config.plugins or {}) do
    local name = plugin.name or plugin_name
    if plugin._ and plugin._.installed and vim.fn.globpath(vim.o.rtp, "colors/" .. name .. ".lua") ~= "" then
      table.insert(themes, name)
    end
  end

  table.sort(themes)
  return themes
end

function M.is_installed(theme)
  local installed = M.get_installed_themes()
  for _, name in ipairs(installed) do
    if name == theme then
      return true
    end
  end
  return false
end

function M.apply(theme)
  if not theme or theme == "" then
    return
  end

  if not M.is_installed(theme) then
    vim.notify("Theme '" .. theme .. "' is not installed", vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(vim.cmd.colorscheme, theme)
  if not ok then
    vim.notify("Could not apply theme '" .. theme .. "': " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.set(theme)
  if not M.is_installed(theme) then
    vim.notify("Theme '" .. theme .. "' is not installed", vim.log.levels.WARN)
    return
  end

  M.save_theme(theme)
  M.apply(theme)
  vim.notify("Theme set to " .. theme, vim.log.levels.INFO)
end

function M.load_saved_theme()
  local theme = M.get_saved_theme()
  vim.schedule(function()
    if M.is_installed(theme) then
      M.apply(theme)
    else
      M.apply(default_theme())
    end
  end)
end

function M.pick_theme()
  local themes = M.get_installed_themes()
  if #themes == 0 then
    vim.notify("No installed themes found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(themes, {
    prompt = "Select theme:",
  }, function(choice)
    if not choice or choice == "" then
      return
    end
    M.set(choice)
  end)
end

vim.api.nvim_create_user_command("Theme", function()
  M.pick_theme()
end, { desc = "Pick a theme" })

return M
