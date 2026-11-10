{ ... }:
{
  # Installs fzf and adds its bash key bindings / completion
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.bash = {
    enable = true;

    bashrcExtra = ''
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
    '';

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      gs = "git status";
      v = "nvim";
      nd = "nix develop";
      "..." = "cd ../..";
      # ssh with keys only root can read, e.g. `sb root@<ip>`
      sb = "pkexec ssh -i /root/.ssh/id_rsa_byda";
      sm = "pkexec ssh -i /root/.ssh/oldmac";
      gp = "GIT_SSH_COMMAND='pkexec ssh -i /root/.ssh/id_rsa_byda -o IdentitiesOnly=yes' git push";
      gpl = "GIT_SSH_COMMAND='pkexec ssh -i /root/.ssh/id_rsa_byda -o IdentitiesOnly=yes' git pull";
      # path: keeps the flake to this directory instead of the whole ~ git repo
      hms = "home-manager switch --flake path:$HOME/.config/home-manager#byda";
    };
  };
}
