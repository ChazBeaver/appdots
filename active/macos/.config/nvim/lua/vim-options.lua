local o = vim.o

-- Editor
o.number = true
o.relativenumber = false
o.clipboard = "unnamedplus"
o.cursorline = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.mouse = "a"
o.title = true
o.ttimeoutlen = 0
o.showmatch = true
o.signcolumn = "yes"
o.scrolloff = 8

-- Search: case-insensitive unless the pattern has a capital; live preview of :s
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

-- New splits open to the right and below
o.splitright = true
o.splitbelow = true

-- Undo history survives closing the file
o.undofile = true
