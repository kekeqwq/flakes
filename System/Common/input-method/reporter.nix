{ pkgs }:
pkgs.writeScriptBin "input-method-tmux-update" ''
  #!${pkgs.python3}/bin/python3
  ${builtins.replaceStrings [ "@TMUX@" "@PS@" ] [ "${pkgs.tmux}/bin/tmux" "${pkgs.procps}/bin/ps" ] (
    builtins.readFile ./tmux-update.py
  )}
''
