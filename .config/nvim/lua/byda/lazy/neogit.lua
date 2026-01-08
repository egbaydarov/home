return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",  -- required
      "sindrets/diffview.nvim", -- optional
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      local neogit = require("neogit")

      neogit.setup()

      vim.keymap.set(
        "n",
        "<leader>gv",
        function()
          neogit.open({ kind = "auto" })
        end,
        { desc = "Open Neogit UI" }
      )
      vim.keymap.set(
        "n",
        "<leader>A",
        function()
          vim.cmd("Git blame")
        end,
        { desc = "Annotate (git blame)" }
      )
      vim.keymap.set(
        "n",
        "<leader>a",
        function()
          vim.cmd("Git blame -L " .. vim.fn.line(".") .. ",+1")
        end,
        { desc = "Annotate (git blame line)" }
      )
    end,
  },

  -- Fugitive: blame-only
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gblame" }
  },
}

