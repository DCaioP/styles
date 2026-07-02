-- 1. Definições globais (DEVEM vir primeiro)
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.deprecation_warnings = false

-- 2. Carregar opções básicas do Vim (melhor carregar antes dos plugins)
require("config.options")

-- 3. Código de instalação do Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 4. Carrega plugins e keymaps
require("lazy").setup("plugins")
require("config.keymaps")

vim.opt.clipboard = "unnamedplus"
