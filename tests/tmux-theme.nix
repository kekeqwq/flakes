{ pkgs, darwin }:
pkgs.runCommand "tmux-native-theme-labels"
  {
    nativeBuildInputs = [ pkgs.tmux ];
    configFile = darwin.config.home-manager.users.keke.xdg.configFile."tmux/tmux.conf".source;
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${pkgs.bash}/bin/bash ${./tmux-theme.sh} "$configFile"
    touch "$out"
  ''
