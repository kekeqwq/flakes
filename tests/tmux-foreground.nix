{ pkgs }:
let
  reporter = import ../System/Common/input-method/reporter.nix { inherit pkgs; };
in
pkgs.runCommand "tmux-foreground-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 -B ${./tmux-foreground.py} ${reporter}/bin/input-method-tmux-update
  touch "$out"
''
