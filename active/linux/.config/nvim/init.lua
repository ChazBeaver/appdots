-- Map <leader>
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader = " "
vim.opt.winbar = "%=%f%="

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Enable True Color Support
vim.opt.termguicolors = true

-- require("themes")           -- loads default theme and :Colortheme
require("lazy").setup("plugins")
require("omarchy_theme_apply").setup()
require("vim-options")
require("remaps")
require("autocmds")
