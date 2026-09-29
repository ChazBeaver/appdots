-- Formatting. Runs on demand with <leader>cf or the gq operator; falls back
-- to the LSP formatter when no tool is listed for the filetype. Formatter
-- binaries are declared in packages/<os>/core.sh.
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true })
      end,
      mode = { "n", "v" },
      desc = "Format buffer or selection",
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      python = { "ruff_organize_imports", "ruff_format" },
      yaml = { "prettier" },
      json = { "prettier" },
      markdown = { "prettier" },
      javascript = { "prettier" },
      terraform = { "terraform_fmt" },
      go = { "gofmt" },
    },
    default_format_opts = { lsp_format = "fallback" },
    -- To format every write instead, add:
    -- format_on_save = { timeout_ms = 500 },
  },
}
