local parsers = {
  "bash",
  "c_sharp",
  "c",
  "diff",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "luap",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "query",
  "regex",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
  "go",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("byda_treesitter", { clear = true }),
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      vim.keymap.set({ "n", "x" }, "<C-space>", function()
        vim.treesitter.select("parent", vim.v.count1)
      end, { desc = "Increment Selection" })
      vim.keymap.set("x", "<bs>", function()
        vim.treesitter.select("child", vim.v.count1)
      end, { desc = "Decrement Selection" })
    end,
  },
}
