-- Language servers through Neovim's built-in client. nvim-lspconfig only
-- supplies each server's defaults from its lsp/ directory; the server
-- binaries are declared in packages/<os>/core.sh.
return {
  "neovim/nvim-lspconfig",
  lazy = false,
  config = function()
    -- No network. Every server below runs as a local child process over
    -- stdin/stdout; these settings turn off the optional features that
    -- would otherwise download something.
    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
            checkThirdParty = false,
          },
          addonManager = { enable = false }, -- would fetch addons from GitHub
          telemetry = { enable = false },
        },
      },
    })
    vim.lsp.config("yamlls", {
      settings = {
        yaml = {
          schemaStore = { enable = false, url = "" }, -- no schemastore.org catalog download
          schemas = {}, -- only local schemas, if you ever add any
        },
        redhat = { telemetry = { enabled = false } },
      },
    })
    vim.lsp.config("bashls", {
      settings = {
        bashIde = { explainshellEndpoint = "" }, -- keep the explainshell.com lookup off
      },
    })

    -- Enable only the servers whose binary is on PATH, so a machine that is
    -- missing one gets no "command not found" on every buffer.
    local servers = {
      lua_ls = "lua-language-server",
      bashls = "bash-language-server",
      yamlls = "yaml-language-server",
      terraformls = "terraform-ls",
      pyright = "pyright-langserver",
    }
    for name, bin in pairs(servers) do
      if vim.fn.executable(bin) == 1 then
        vim.lsp.enable(name)
      end
    end

    -- Built-in completion: <C-n>/<C-p> move, <C-y> accepts, <C-e> dismisses.
    vim.o.completeopt = "menu,menuone,noselect,fuzzy,popup"

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
        end
        -- Neovim already maps K (hover), grn (rename), gra (code action),
        -- grr (references), gri (implementation), gO (symbols), [d and ]d.
        map("gd", vim.lsp.buf.definition, "LSP definition")
        map("gD", vim.lsp.buf.declaration, "LSP declaration")
        map("gy", vim.lsp.buf.type_definition, "LSP type definition")
        if client and client:supports_method("textDocument/completion") then
          vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
        end
      end,
    })
  end,
}
