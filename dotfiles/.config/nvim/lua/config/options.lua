-- Opções gerais do Neovim
local opt = vim.opt

-- Interface
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true

-- Indentação
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Busca
opt.ignorecase = true
opt.smartcase = true

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- Split windows
opt.splitright = true
opt.splitbelow = true

-- Clipboard
opt.clipboard = "unnamedplus"

-- Undo
opt.undofile = true
opt.undolevels = 10000

-- Markdown
opt.conceallevel = 2
