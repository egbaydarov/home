local map = vim.keymap.set

map("n", "-", "<cmd>Oil<cr>", { desc = "open parent directory"})

map("n", "<leader>/", function()
  local justatool = require("byda.justatool")
  local current_buf = vim.api.nvim_buf_get_name(0)
  local context_file = vim.fn.expand("~/.config/justatool/CURRENT")

  if current_buf ~= context_file then
    return
  end

  justatool.run_llm()
end, { desc = "justatool run LLM on CURRENT" })

map("v", "<leader>/", function()
  -- Exit visual mode to ensure marks are set
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, 'x', false)
  -- Small delay to ensure marks are properly set
  vim.defer_fn(function()
    require('byda.justatool').add_to_context()
  end, 10)
end, { desc = "justatool add selection to context" })
