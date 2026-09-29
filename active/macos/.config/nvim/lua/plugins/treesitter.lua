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

      -- The main branch has no ensure_installed; install what is missing.
      -- Needs the tree-sitter CLI and a C compiler on PATH.
      local ensure_installed = {
        "bash", "c", "dockerfile", "go", "hcl", "javascript", "json", "lua",
        "markdown", "markdown_inline", "python", "terraform", "toml", "yaml",
      }
      local installed = ts_config.get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
      end, ensure_installed)
      if #missing > 0 then
        nts.install(missing)
      end

      -- Highlighting and indentation are opt-in per buffer on main.
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
