return{
  "ThePrimeagen/harpoon",
	branch = "harpoon2",
	config = function()
		local harpoon = require("harpoon")
		---@diagnostic disable-next-line: missing-parameter
		harpoon:setup()
		local function map(lhs, rhs, opts)
                vim.keymap.set("n", lhs, rhs, opts or {})
		end
		map("<leader>a", function() harpoon:list():add() end)
		map("<leader>h", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
		map("<c-h><c-h>", function() harpoon:list():select(1) end)
		map("<c-h><c-j>", function() harpoon:list():select(2) end)
		map("<c-h><c-k>", function() harpoon:list():select(3) end)
		map("<c-h><c-l>", function() harpoon:list():select(4) end)
		map("<c-h><c-y>", function() harpoon:list():select(5) end)
		map("<c-h><c-u>", function() harpoon:list():select(6) end)
		map("<c-h><c-i>", function() harpoon:list():select(7) end)
		map("<c-h><c-o>", function() harpoon:list():select(8) end)
	end
}
