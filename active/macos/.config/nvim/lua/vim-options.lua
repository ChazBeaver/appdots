local o = vim.o

-- Editor
o.number = true
o.relativenumber = false
o.clipboard = "unnamedplus"
o.cursorline = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
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

-- Filetype plugins (including Markdown/Python) and EditorConfig can override
-- the defaults above. Reapply the two-space preference when displaying a file.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("AppdotsIndent", { clear = true }),
  callback = function(event)
    local buffer = vim.bo[event.buf]
    if buffer.buftype ~= "" then
      return
    end
    buffer.tabstop = 2
    buffer.softtabstop = 2
    buffer.shiftwidth = 2
    buffer.vartabstop = ""
    buffer.varsofttabstop = ""
    -- Make recipes require literal tabs; they still display two columns wide.
    buffer.expandtab = buffer.filetype ~= "make"
  end,
})
