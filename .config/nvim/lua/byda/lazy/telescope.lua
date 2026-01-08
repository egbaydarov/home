return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
        require('telescope').setup({})
        local builtin = require('telescope.builtin')

        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
        vim.keymap.set('n', '<leader>fg', builtin.git_files, { desc = 'Telescope find git' })
        vim.keymap.set('n', '<leader>gg', builtin.live_grep, { desc = 'Telescope live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
        vim.keymap.set("n", "<leader>q", ":bd<CR>", {desc = 'Close current buffer'})

        vim.keymap.set("n", "<leader>j", ":cnext<CR>", {desc = 'Next quickfix'})
        vim.keymap.set("n", "<leader>k", ":cprev<CR>", {desc = 'Prev quickfix'})
    end
}
