local global = vim.g
local o = vim.o
 
vim.scriptencoding = "utf-8"
 
-- Map <leader>
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct
--  
-- -- Return Keymap
-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
 
-- Editor Options
o.number = true
o.relativenumber = false
o.clipboard = "unnamedplus"
o.syntax = "on"
o.autoindent = true
o.cursorline = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.encoding = "utf-8"
o.ruler = true
o.mouse = "a"
o.title = true
o.hidden = true
o.ttimeoutlen = 0
o.wildmenu = true
o.showcmd = true
o.showmatch = true
-- o.inccomand = "split"
-- o.splitbelow = "splitright"vim.cmd("set number")
-- vim.cmd("set mouse=a")
-- vim.cmd("syntax enable")
-- vim.cmd("set showcmd")
-- vim.cmd("set encoding=utf-8")
-- vim.cmd("set showmatch")
-- vim.cmd("set relativenumber")
-- vim.cmd("set expandtab")
-- vim.cmd("set tabstop=4")
-- vim.cmd("set shiftwidth=0")
-- vim.cmd("set softtabstop=0")
-- vim.cmd("set autoindent")
-- vim.cmd("set smarttab")

-- NOTE the following two conflict with Harpoon2
-- vim.keymap.set('n', '<C-h>', '<C-w>h', {})
-- vim.keymap.set('n', '<C-l>', '<C-w>l',{})
