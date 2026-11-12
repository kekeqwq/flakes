{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  source = ./input-method;
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
          pkgs.nodejs
        ];
      }
      ''
        for file in ${source}/*.lua; do luac -p "$file"; done
        lua ${source}/policy.test.lua ${source}/policy.lua
        lua ${source}/manager.test.lua ${source}/init.lua
        node ${source}/pi-ime.test.mjs ${source}/pi-ime.ts
        mkdir -p "$out"
        cp ${source}/* "$out/"
        substituteInPlace "$out/init.lua" \
          --replace-fail '@INPUT_SOURCE_SELECT@' '${sourceActuator}/bin/input-method-select'
      '';
  tmuxReporter = pkgs.writeScriptBin "input-method-tmux-update" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.replaceStrings [ "@TMUX@" ] [ "${pkgs.tmux}/bin/tmux" ] (
      builtins.readFile (source + /tmux-update.py)
    )}
  '';
  hooks = [
    "client-attached"
    "client-detached"
    "client-session-changed"
    "session-window-changed"
    "after-select-pane"
    "after-select-window"
    "after-new-window"
    "after-split-window"
    "pane-mode-changed"
    "pane-exited"
    "pane-died"
    "window-pane-changed"
  ];
in
{
  homebrew.casks = [ "hammerspoon" ];
  environment.systemPackages = [ tmuxReporter ];
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
      ".pi/agent/extensions/input-method.ts".source = "${checkedSource}/pi-ime.ts";
    };
    xdg.configFile."wezterm/input-method.lua".source = "${checkedSource}/wezterm.lua";
    home.activation.inputMethodState = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.local/state/input-method/"{pi,tmux}
      chmod 700 "$HOME/.local/state/input-method" "$HOME/.local/state/input-method/"{pi,tmux}
    '';
    programs.wezterm.settings.status_update_interval = 100;
    programs.wezterm.extraConfig = lib.mkAfter ''
      if wezterm.target_triple == "aarch64-apple-darwin" then
        local imeConfig = wezterm.config_dir .. "/input-method.lua"
        wezterm.add_to_config_reload_watch_list(imeConfig)
        dofile(imeConfig).apply()
      end
    '';
    programs.tmux.extraConfig = lib.mkAfter (
      lib.concatMapStringsSep "\n" (
        hook:
        ''set-hook -g '${hook}[90]' 'run-shell -b "${tmuxReporter}/bin/input-method-tmux-update #{q:socket_path}"' ''
      ) hooks
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
