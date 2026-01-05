local map = vim.keymap.set

map("n", "-", "<cmd>Oil<cr>", { desc = "open parent directory"})

map("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition"})
map("n", "<leader>gr", vim.lsp.buf.references, { desc = "Find references"})
map("n", "<leader>gi", vim.lsp.buf.implementation, { desc = "Go to implementation"})
map("n", "<leader>h", vim.lsp.buf.hover, { desc = "Hover documentation" })
map("n", "<leader>r", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader><CR>", vim.lsp.buf.code_action, { desc = "Code actions" })
map("n", "<leader>s", vim.lsp.buf.signature_help, { desc = "Show signature" })
map("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format code" })

local diagnostic_goto = function(severity)
  local go = vim.diagnostic.jump
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function()
    go({count = 1, float = true, severity = severity})
  end
end
map("n", "<leader>e", diagnostic_goto(), { desc = "Next Diagnostic" })

