{ pkgs, pkgsUnstable, ... }:
let
  sdk = pkgs.dotnet-sdk_10;
in
{
  home.packages = [
    sdk
    # roslyn.nvim needs >= 5.12; 26.05 only has 5.7
    pkgsUnstable.roslyn-ls
  ];

  home.sessionVariables = {
    # Framework-dependent apphosts (bin/Debug/.../App) look the runtime up here
    DOTNET_ROOT = "${sdk}/share/dotnet";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
  };
}
