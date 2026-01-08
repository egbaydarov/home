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
        local cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
          "--query-driver=/nix/store/*mingw*/bin/x86_64-w64-mingw32-*"
        }
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

        local map = vim.keymap.set
        map("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition"})
        map("n", "<leader>gr", vim.lsp.buf.references, { desc = "Find references"})
        map("n", "<leader>gi", vim.lsp.buf.implementation, { desc = "Go to implementation"})
        map("n", "<leader>h", vim.lsp.buf.hover, { desc = "Hover documentation" })
        map("n", "<leader>r", vim.lsp.buf.rename, { desc = "Rename symbol" })
        map("n", "<leader><CR>", vim.lsp.buf.code_action, { desc = "Code actions" })
        map("n", "<leader>s", vim.lsp.buf.signature_help, { desc = "Show signature" })
        map("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format code" })

        local diagnostic_goto = function(count)
          local go = vim.diagnostic.jump
          return function()
            go({count = count, float = true, _highest = true})
          end
        end

        map("n", "]]", diagnostic_goto(1), { desc = "Next Diagnostic" })
        map("n", "[[", diagnostic_goto(-1), { desc = "Prev Diagnostic" })
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
