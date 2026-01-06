return {
{
    'hrsh7th/nvim-cmp',
    event = "InsertEnter", -- Load on entering insert mode
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'saadparwaiz1/cmp_luasnip', -- Optional: For LuaSnip support
      'L3MON4D3/LuaSnip', -- Optional: LuaSnip for snippets
    },
    config = function()
      -- Set up nvim-cmp
      local cmp = require('cmp')

      cmp.setup({
        snippet = {
          expand = function(args)
            require('luasnip').lsp_expand(args.body) -- For LuaSnip support
          end,
        },
        mapping = {
          ['<C-S>'] = cmp.mapping.complete(),
          ['<TAB>'] = cmp.mapping.confirm({ select = true }),
          ['<Up>'] = cmp.mapping.select_prev_item(),
          ['<Down>'] = cmp.mapping.select_next_item(),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'buffer' },
          { name = 'path' },
          { name = 'easy-dotnet' },
          { name = "vim-dadbod-completion" },
        },
      })

      -- Enable LSP capabilities for nvim-cmp
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      vim.lsp.config('pyright', {
        capabilities = capabilities
      })
    end,
  }}
