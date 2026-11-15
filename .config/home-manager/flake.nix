{
  description = "home-manager configuration";

  inputs = {
    # Same release as the NixOS system
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Fast-moving dev toolchains (Go, linters)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      system = "x86_64-linux";
      # builtins.getEnv returns "" unless evaluated with --impure.
      username =
        let user = builtins.getEnv "USER";
        in if user != "" then user
        else throw "USER is unset: run home-manager with --impure";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit pkgsUnstable username; };
        modules = [ ./home.nix ];
      };
    };
}
