{ pkgs, ... }:
{
  # RAD Debugger for native code: C, Go, .NET NativeAOT
  home.packages = [
    (pkgs.callPackage ../pkgs/raddebugger/package.nix { })
  ];
}
