return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",

    -- ✅ keep its deps in your override so they don't get dropped
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },

    -- ✅ guarantee it doesn't load at startup
    cmd = "Neotree",
    keys = {
      { "<C-n>", "<cmd>Neotree toggle left<CR>", desc = "Toggle Neo-tree" },
    },
  },
}
