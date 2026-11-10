{ config, pkgs, ... }:
{
  home.username = "byda";
  home.homeDirectory = "/home/byda";
  home.stateVersion = "25.11";
  programs.bash = {
    enable = true;
  };
  programs.bash.bashrcExtra = ''
    runbg () {
      [ -n "$${TMUX:-}" ] || { echo "runbg: not inside tmux" >&2; return 1; }
      [ $# -gt 0 ] || { echo "usage: runbg <command...>" >&2; return 2; }

      local win=1000
      local cmd="$*"

      if ! tmux list-windows -F '#{window_index}' | grep -qx "$win"; then
        tmux new-window -d -t "$win" -n "bg" -c "$PWD"
      fi

      tmux split-window -t "$${win}" -c "$PWD" "$cmd"
      tmux select-layout -t "$${win}" tiled
    }

    eval "$(fzf --bash)"
    alias nd='nix develop'
  '';
  programs.bash.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    gs = "git status";
    v = "nvim";
    curb = "nohup cursor . > /dev/null 2>&1 &";
    "..." = "cd ../..";
  };

  xdg.desktopEntries = {
    qvidcap = {
      name = "qvidcap";
      noDisplay = true;
    };
    qv4l2 = {
      name = "qv4l2";
      noDisplay = true;
    };
    "org.gtk.gtk4.NodeEditor" = {
      name = "GTK4 Node Editor";
      noDisplay = true;
    };
    "org.gtk.WidgetFactory4" = {
      name = "GTK4 Widget Factory";
      noDisplay = true;
    };
    "org.gtk.PrintEditor4" = {
      name = "GTK4 Print Editor";
      noDisplay = true;
    };
    "org.gtk.Demo4" = {
      name = "GTK4 Demo";
      noDisplay = true;
    };
    "nvim" = {
      name = "Neovim";
      noDisplay = true;
    };
    "nvidia-settings" = {
      name = "Nvidia X";
      noDisplay = true;
    };
    "nixos-manual" = {
      name = "NixOS Manual";
      noDisplay = true;
    };
  };

  programs.home-manager.enable = true;
  #systemd.user.services.twitchalarm = {
  #  Unit = {
  #    Description = "Twitch Notifier";
  #    After = [ "network.target" ];
  #  };
  #  Service = {
  #    ExecStart = "${pkgs.callPackage ./twitchalarm.nix { }}/bin/twitch-notifs";
  #    Restart = "always";
  #    RestartSec = "5s";
  #    StartLimitIntervalSec = 30;
  #    StartLimitBurst = 10;
  #    EnvironmentFile = "/etc/twitchalarm.env";
  #  };
  #  Install = {
  #    WantedBy = [ "default.target" ];
  #  };
  #};
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    pkgs.dbeaver-bin
    pkgs.tree-sitter # nvim-treesitter (main) builds parsers with it
    #(import ./twitchalarm.nix { inherit pkgs; })
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    #".bashrc".text = ''
    #  eval "$(fzf --bash)"
    #'';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/byda/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };
}
