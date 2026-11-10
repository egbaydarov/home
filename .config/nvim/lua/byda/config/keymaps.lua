local map = vim.keymap.set

vim.opt.langmap = {
  -- Uppercase (Shifted)
  [[ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ;QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<?~]],
  -- Lowercase
  [[йцукенгшщзхъфывапролджэячсмитьбюё;qwertyuiop[]asdfghjkl;'zxcvbnm\,/`]],
}

map("n", "-", "<cmd>Oil<cr>", { desc = "open parent directory"})
