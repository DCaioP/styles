local keymap = vim.keymap.set

-- Markdown Preview
keymap("n", "<leader>mp", ":MarkdownPreviewToggle<CR>", { desc = "Markdown Preview" })

-- Tabelas (Table Mode)
keymap("n", "<leader>mt", ":TableModeToggle<CR>", { desc = "Toggle Table Mode" })
