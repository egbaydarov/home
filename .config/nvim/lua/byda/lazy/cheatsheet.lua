return {
  'sudormrfbin/cheatsheet.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/popup.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function ()
      vim.keymap.set("n", "<F3>", function() vim.cmd("Cheatsheet") end, { desc = "open cheatsheet tab" })
  end
}

