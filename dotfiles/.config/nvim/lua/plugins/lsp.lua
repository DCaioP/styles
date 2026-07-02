return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim"
    },
    config = function()
      require("mason").setup()

      -- Configuração combinada Mason + LSPConfig
      require("mason-lspconfig").setup({
        ensure_installed = { "marksman" }, -- Garante que o marksman esteja instalado

        -- 'handlers' configura automaticamente os servidores listados acima
        handlers = {
          function(server_name)
            require("lspconfig")[server_name].setup({})
          end,
        }
      })
    end,
  }
}
