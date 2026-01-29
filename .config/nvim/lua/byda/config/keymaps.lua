local map = vim.keymap.set

map("n", "-", "<cmd>Oil<cr>", { desc = "open parent directory"})

map("n", "<leader>/", function()
  require("byda.justatool").run_llm()
end, { desc = "justatool run LLM on CURRENT" })

map("v", "<leader>/", "<Esc><cmd>lua require('byda.justatool').add_to_context()<CR>", { desc = "justatool add selection to context" })