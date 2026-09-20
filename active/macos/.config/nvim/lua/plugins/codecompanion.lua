-- lua/plugins/codecompanion.lua
return {
  "olimorris/codecompanion.nvim",
  version = "^19.0.0",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  keys = {
    { "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "AI chat" },
    { "<leader>cx", "<cmd>CodeCompanionCLI<cr>",         desc = "Codex agent" },
    { "<leader>ca", "<cmd>CodeCompanionActions<cr>",     desc = "AI actions" },
    { "<leader>ci", ":CodeCompanion ", mode = { "n", "v" }, desc = "AI inline edit" },
  },
  opts = {
    adapters = {
      http = {
        litellm = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            env = {
              url = vim.env.LITELLM_BASE_URL,   -- resolved by Lua, no ambiguity
              api_key = "LITELLM_API_KEY",      -- env var NAME, looked up at runtime
              chat_url = "/v1/chat/completions",
              models_endpoint = "/v1/models",
            },
            schema = { model = { default = vim.env.LITELLM_MODEL or "gpt-5.4" } },
          })
        end,
      },
    },
    interactions = {
      chat   = { adapter = "litellm" },
      inline = { adapter = "litellm" },
      cmd    = { adapter = "litellm" },
      cli = {
        agent = "codex",
        agents = {
          codex = { cmd = "codex", args = { "--model", "gpt-5.4"}, description = "OpenAI Codex CLI" },
        },
      },
    },
    opts = {
      log_level = "DEBUG",   -- NOTE: nested inside opts.opts, not top-level
    },
  },
}
