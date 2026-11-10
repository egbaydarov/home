{ pkgs, pkgsUnstable, ... }:
{
  programs.go = {
    enable = true;
    package = pkgsUnstable.go_latest;
    # Written to ~/.config/go/env, so go, gopls and dlv agree no matter how
    # they are started. Without CC, go looks for `gcc`, finds none, and
    # silently disables cgo (breaking packages like confluent-kafka-go).
    env = {
      CGO_ENABLED = "1";
      CC = "${pkgs.clang}/bin/clang";
      CXX = "${pkgs.clang}/bin/clang++";
    };
  };

  home.packages = with pkgsUnstable; [
    gopls
    gotools # goimports, gorename, ...
    golangci-lint
    pkg-config
  ];
}
