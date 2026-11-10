{ pkgs, ... }:
{
  # Tools the nvim config expects on PATH
  home.packages = with pkgs; [
    tree-sitter # nvim-treesitter (main) builds parsers with it
    stylua # conform: lua
    lua-language-server
    ripgrep # telescope live_grep, grepprg
    fd # telescope find_files
  ];
}
