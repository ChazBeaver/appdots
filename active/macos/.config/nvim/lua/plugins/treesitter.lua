return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- If the plugin isn't fully cloned yet (e.g. first launch after a wipe),
      -- skip quietly. Run :Lazy sync, then restart.
      local ok_main, nts = pcall(require, "nvim-treesitter")
      local ok_cfg, ts_config = pcall(require, "nvim-treesitter.config")
      if not (ok_main and ok_cfg) then
        return
      end

      nts.setup()

      local ensure_installed = { "lua", "bash", "c", "javascript", "go" }
      local installed = ts_config.get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
      end, ensure_installed)
      if #missing > 0 then
        nts.install(missing)
      end

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr =
              "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
