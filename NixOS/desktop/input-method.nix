{
  config,
  pkgs,
  lib,
  ...
}:
let
  shared = ../../System/Common/input-method;
  # Reuse the shared reporter so tmux/pane identity matches macOS.
  tmuxReporter = import (shared + "/reporter.nix") { inherit pkgs; };
  tmuxHooks = import (shared + "/tmux-hooks.nix") { reporter = tmuxReporter; };
  # The pure policy runs its tests while the watcher is built.
  watcher =
    pkgs.runCommand "input-method-watch"
      {
        nativeBuildInputs = [
          pkgs.python3
        ];
      }
      ''
        python3 ${./input-method/policy.test.py} ${./input-method/policy.py}
        mkdir -p "$out/bin" "$out/lib"
        cp ${./input-method/policy.py} "$out/lib/policy.py"
        cp ${./input-method/watch.py} "$out/lib/watch.py"
        printf '#!${pkgs.python3}/bin/python3\n' > "$out/bin/input-method-watch"
        cat ${./input-method/watch.py} >> "$out/bin/input-method-watch"
        printf '#!${pkgs.python3}/bin/python3\n' > "$out/bin/input-method-hold"
        cat ${./input-method/hold.py} >> "$out/bin/input-method-hold"
        substituteInPlace "$out/bin/input-method-watch" \
          --replace-fail '@DIR@' "$out/lib" \
          --replace-fail '@NIRI@' "${pkgs.niri}" \
          --replace-fail '@FCITX5_REMOTE@' "${pkgs.qt6Packages.fcitx5-with-addons}"
        substituteInPlace "$out/lib/watch.py" \
          --replace-fail '@DIR@' "$out/lib" \
          --replace-fail '@NIRI@' "${pkgs.niri}" \
          --replace-fail '@FCITX5_REMOTE@' "${pkgs.qt6Packages.fcitx5-with-addons}"
        substituteInPlace "$out/bin/input-method-hold" \
          --replace-fail '@DIR@' "$out/lib" \
          --replace-fail '@FCITX5_REMOTE@' "${pkgs.qt6Packages.fcitx5-with-addons}" \
          --replace-fail '@TMUX@' "${pkgs.tmux}"
        chmod +x "$out/bin/input-method-watch" "$out/bin/input-method-hold"
      '';
in
{
  environment.systemPackages = [
    tmuxReporter
    watcher
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      # Never ignore the user directory: each instance keeps its own training.
      ignoreUserConfig = false;
      addons = with pkgs; [
        catppuccin-fcitx5
        (fcitx5-rime.override { rimeDataPkgs = [ rime-ice ]; })
      ];
    };
  };

  # Manage individual static files, not the whole Rime directory. userdb,
  # installation.yaml, user.yaml and build caches remain local to the instance.
  myuser.hm = {
    xdg.configFile = {
      "fcitx5/profile" = {
        force = true;
        text = ''
          [Groups/0]
          Name=Default
          Default Layout=us
          DefaultIM=rime

          [Groups/0/Items/0]
          Name=keyboard-us
          Layout=

          [Groups/0/Items/1]
          Name=rime
          Layout=

          [GroupOrder]
          0=Default
        '';
      };
      "fcitx5/config" = {
        force = true;
        text = ''
          [Hotkey/TriggerKeys]
          0=Control+Shift+space

          [Behavior]
          ActiveByDefault=False
          ShareInputState=No
          PreeditEnabledByDefault=True
        '';
      };
      "fcitx5/conf/classicui.conf" = {
        force = true;
        text = ''
          Theme=catppuccin-mocha-mauve
          DarkTheme=catppuccin-mocha-mauve
          UseDarkTheme=True
        '';
      };
    };
    xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
      force = true;
      text = ''
        patch:
          __include: rime_ice_suggestion:/
          schema_list:
            - schema: double_pinyin_flypy
      '';
    };
  };

  # Pi inside WezTerm gets Chinese; Emacs and non-editor surfaces get ASCII.
  # Nothing here writes prompt text, only focus metadata.
  myuser.hm.systemd.user.services.input-method-watch = {
    Unit = {
      Description = "Apply fcitx5 state from focus reports";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watcher}/bin/input-method-watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  myuser.hm.programs.tmux.extraConfig = lib.mkAfter (
    builtins.concatStringsSep "\n" tmuxHooks
    + ''

      # Prefix switches fcitx5 to ASCII before tmux reads the shortcut key.
      bind-key -T root C-b run-shell "${watcher}/bin/input-method-hold begin #{socket_path}" \; switch-client -T prefix
      bind-key -T root C-Space run-shell "${watcher}/bin/input-method-hold begin #{socket_path}" \; switch-client -T prefix
      bind-key -T prefix Escape run-shell "${watcher}/bin/input-method-hold end #{socket_path}" \; switch-client -T root
      set-hook -g after-bind-key[91] 'run-shell -b "${watcher}/bin/input-method-hold settle #{socket_path}"'
    ''
  );

  # Keep the reporter's state directory owner-only.
  systemd.tmpfiles.rules = [
    "d ${
      config.users.users.${config.myuser.name}.home
    }/.local/state/input-method 0700 ${config.myuser.name} - -"
  ];
}
