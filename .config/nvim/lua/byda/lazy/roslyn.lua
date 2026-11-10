return {
  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    opts = {},
    config = function(_, opts)
      -- Nix's roslyn-ls ships the server itself, not the `roslyn-language-server`
      -- daemon client the plugin defaults to.
      vim.lsp.config("roslyn", {
        cmd = {
          "Microsoft.CodeAnalysis.LanguageServer",
          "--stdio",
          "--clientProcessId",
          tostring(vim.uv.os_getpid()),
          "--extensionLogDirectory",
          vim.fs.joinpath(vim.fn.stdpath("log"), "roslyn"),
        },
      })
      require("roslyn").setup(opts)
    end,
  },
}
