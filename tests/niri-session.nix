{ pkgs }:
let
  patched = import ../NixOS/desktop/niri/session-package.nix { inherit pkgs; };
in
pkgs.runCommand "niri-session-environment-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  bash -n ${patched}/bin/niri-session
  python3 ${../NixOS/desktop/niri/session.test.py} ${pkgs.niri}/bin/niri-session ${patched}/bin/niri-session
  touch "$out"
''
