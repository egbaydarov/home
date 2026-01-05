return {
  {
    "neovim/nvim-lspconfig",
    config = function()
        vim.lsp.enable("lua_ls")
        vim.lsp.config("lua_ls", {
          on_attach = on_attach,
          capabilities = capabilities,
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },

              workspace = {
                library = {
                  -- This loads Neovim's runtime (including type definitions)
                  vim.fn.expand("$VIMRUNTIME/lua"),
                  vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
                },
                checkThirdParty = false,
              },
            },
          },
        })

        vim.lsp.enable("clangd")
        local mingw = vim.fn.exepath("x86_64-w64-mingw32-g++")
        local cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
        }
        if mingw ~= "" then
          table.insert(cmd, "--query-driver=" .. mingw)
        end
        vim.lsp.config("clangd", {
          cmd = cmd
        })

        vim.lsp.enable("gopls", true)
        vim.lsp.config("gopls",{
           on_attach = on_attach,
           capabilities = capabilities,
           settings = {
             gopls = {
               completeUnimported = true,
               usePlaceholders = true,
               analyses = {
                 unusedparams = true,
               }
             }
           }
        })
    end
  },
  {
    'stevearc/conform.nvim',
    opts = {},
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          go = { "gofmt" },
          c = { "clang-format" },
          cpp = { "clang-format" },
          --python = { "isort", "black" },
          --rust = { "rustfmt", lsp_format = "fallback" },
          --javascript = { "prettierd", "prettier", stop_after_first = true },
        },
      })
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        callback = function(args)
          require("conform").format({ bufnr = args.buf })
        end,
      })
    end
  }
}
