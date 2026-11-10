{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # languages / runtimes
    python3
    nodejs

    # C / C++
    clang # also provides cc
    clang-tools # clangd, clang-format
    cmake

    # data / API
    jq
    yq
    grpcurl

    # GUIs
    mongodb-compass
    lens
  ];
}
