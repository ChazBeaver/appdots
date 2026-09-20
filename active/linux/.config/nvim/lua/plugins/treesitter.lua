-- BULLETPROOF VERSION --
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function() --Catches both legacy and modern potentials
      local ok, ts = pcall(require, "nvim-treesitter.configs") --legacy=configs
      if not ok then
        ts = require("nvim-treesitter.config") --modern=config
      end

      ts.setup({
        ensure_installed = { "lua", "bash", "c", "javascript", "go" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}
