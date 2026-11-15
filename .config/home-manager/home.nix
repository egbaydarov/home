{ pkgs, username, ... }:
{
  imports = [
    ./modules/shell.nix
    ./modules/desktop.nix
    ./modules/editor.nix
    ./modules/dev.nix
    ./modules/go.nix
    ./modules/dotnet.nix
    ./modules/debug.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = [
    pkgs.dbeaver-bin
    #(import ./twitchalarm.nix { inherit pkgs; })
  ];
}
