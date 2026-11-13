{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  source = ./input-method;
  shared = ../../System/Common/input-method;
  sourceActuator = pkgs.stdenv.mkDerivation {
    pname = "input-method-select";
    version = "1";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/bin"
      $CC -O2 -fobjc-arc -framework Cocoa -framework Carbon \
        ${source}/select-source.m -o "$out/bin/input-method-select"
    '';
  };
  checkedSource =
    pkgs.runCommand "input-method-config"
      {
        nativeBuildInputs = [
          pkgs.lua
        ];
      }
      ''
        for file in ${source}/*.lua; do luac -p "$file"; done
        lua ${source}/policy.test.lua ${source}/policy.lua
        lua ${source}/manager.test.lua ${source}/init.lua
        mkdir -p "$out"
        cp ${source}/* "$out/"
        substituteInPlace "$out/init.lua" \
          --replace-fail '@INPUT_SOURCE_SELECT@' '${sourceActuator}/bin/input-method-select'
      '';
  tmuxReporter = import (shared + "/reporter.nix") { inherit pkgs; };
  prefixSwitcher = pkgs.writeScriptBin "input-method-prefix" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.replaceStrings
      [ "@SELECT@" "@TMUX@" "@REPORTER@" ]
      [
        "${sourceActuator}/bin/input-method-select"
        "${pkgs.tmux}/bin/tmux"
        "${tmuxReporter}/bin/input-method-tmux-update"
      ]
      (builtins.readFile (source + /prefix.py))
    }
  '';
  tmuxHooks = import (shared + "/tmux-hooks.nix") {
    reporter = tmuxReporter;
  };
in
{
  homebrew.casks = [ "hammerspoon" ];
  environment.systemPackages = [
    tmuxReporter
    prefixSwitcher
  ];
  my.inputMethod.prefixCommand = "${prefixSwitcher}/bin/input-method-prefix";
  myuser.hm = {
    home.file = {
      ".hammerspoon/init.lua" = {
        source = "${checkedSource}/init.lua";
        onChange = ''
          if /usr/bin/pgrep -x Hammerspoon >/dev/null; then
            /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'hs.reload()' >/dev/null 2>&1 || true
          fi
        '';
      };
      ".hammerspoon/ime_policy.lua" = {
        source = "${checkedSource}/policy.lua";
        onChange = ''
          if /usr/bin/pgrep -x Hammerspoon >/dev/null; then
            /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'hs.reload()' >/dev/null 2>&1 || true
          fi
        '';
      };
    };
    home.activation.inputMethodState = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.local/state/input-method/"{pi,tmux}
      chmod 700 "$HOME/.local/state/input-method" "$HOME/.local/state/input-method/"{pi,tmux}
    '';
    programs.wezterm.settings.status_update_interval = 100;
    programs.tmux.extraConfig = lib.mkAfter (
      builtins.concatStringsSep "\n" tmuxHooks
      + ''

        # WezTerm signals the prefix before tmux sees it; these only restore.
        # Esc cancels the prefix, after-bind-key covers every other shortcut.
        bind-key -T prefix Escape run-shell -b "${prefixSwitcher}/bin/input-method-prefix end #{socket_path} --force" \; switch-client -T root
        set-hook -g after-bind-key[91] 'run-shell -b "${prefixSwitcher}/bin/input-method-prefix settle #{socket_path}"'
      ''
    );
    launchd.agents.input-method = {
      enable = true;
      config = {
        Label = "org.nix.input-method";
        ProgramArguments = [
          "/usr/bin/open"
          "-g"
          "-a"
          "/Applications/Hammerspoon.app"
        ];
        RunAtLoad = true;
        ProcessType = "Background";
      };
    };
  };
}
