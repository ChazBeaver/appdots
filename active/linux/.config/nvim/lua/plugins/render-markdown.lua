-- Render headings, checkboxes, tables and code blocks in markdown buffers.
-- The cursor line shows raw text, so editing still sees the real markup.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  opts = {},
}
