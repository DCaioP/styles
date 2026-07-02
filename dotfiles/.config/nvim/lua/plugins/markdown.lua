return {
  -- 1. Renderização visual
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { "markdown", "quarto" },
    opts = {},
  },

  -- 2. Preview no Navegador
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_auto_start = 0
    end,
    ft = { "markdown" },
  },

  -- 3. Tabelas
  { "dhruvasagar/vim-table-mode", ft = { "markdown" } },

  -- 4. Treesitter (Ajustado para evitar o erro de 'module not found')
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- No Neovim 0.11, usamos pcall para evitar que o erro trave o editor
      local status, ts_config = pcall(require, "nvim-treesitter.configs")
      if status then
        ts_config.setup({
          ensure_installed = { "markdown", "markdown_inline", "lua", "vim" },
          highlight = { enable = true },
        })
      end
    end,
  },
}
