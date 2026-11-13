{ pkgs }:
pkgs.writeScriptBin "input-method-tmux-update" ''
  #!${pkgs.python3}/bin/python3
  ${builtins.replaceStrings [ "@TMUX@" ] [ "${pkgs.tmux}/bin/tmux" ] (
    builtins.readFile ./tmux-update.py
  )}
''
