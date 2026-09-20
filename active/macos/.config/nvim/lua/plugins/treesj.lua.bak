return {
	"Wansmer/treesj",
	keys = {"<space>m", "<space>j", "<space>s"},
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("treesj").setup({})
	end,
}

-- Solutions to Force Plugin Load
--
-- If you want treesj to be fully loaded on startup (and avoid showing it in the "not loaded" section), you can change the plugin configuration to either:
--
--     Remove the keys Option: This will make the plugin load immediately when Neovim starts.
--     Set lazy = false: This will force the plugin to load immediately on startup.
--
-- Here's how you can modify the configuration:
-- Solution 1: Remove the keys Option
--
-- Example 1
--
-- return {
--   "Wansmer/treesj",
--   dependencies = { "nvim-treesitter/nvim-treesitter" },
--   config = function()
--     require("treesj").setup({})
--   end,
-- }
--
-- With the keys option removed, Lazy.nvim will treat treesj as a regular plugin and load it on startup.
-- Solution 2: Set lazy = false
--
-- Exmple 2
--
-- return {
--   "Wansmer/treesj",
--   lazy = false,
--   dependencies = { "nvim-treesitter/nvim-treesitter" },
--   config = function()
--     require("treesj").setup({})
--   end,
-- }
--
-- By adding lazy = false, you instruct Lazy.nvim to load the plugin immediately, even if keybindings are defined.
