{ pkgs, darwin }:
pkgs.runCommand "tmux-native-theme-labels"
  {
    nativeBuildInputs = [
      pkgs.tmux
      pkgs.python3
      pkgs.coreutils
    ];
    configFile = darwin.config.home-manager.users.keke.xdg.configFile."tmux/tmux.conf".source;
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${pkgs.bash}/bin/bash ${./tmux-theme.sh} "$configFile"
    python3 -I ${./tmux-popup.py} "$configFile"
    touch "$out"
  ''
