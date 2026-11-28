{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  hm = config.home-manager.users.${config.myuser.name};
  root = "${hm.xdg.stateHome}/keke-appearance";
  paint = import ./appearance-palette.nix;
  accentFor = import ./appearance-accent.nix;
  palettes = lib.genAttrs [ "light" "dark" ] (mode: {
    "panel.css" = pkgs.writeText "panel-${mode}.css" (
      let
        accent = accentFor mode;
      in
      ''
        ${paint mode (builtins.readFile ../../pkgs/keke-waybar-panel/panel.css)}
        @define-color panel_accent ${accent.fill};
        @define-color panel_on_accent ${accent.onFill};
        @define-color panel_accent_text ${accent.text};
      ''
    );
    "ghostty-overlays.css" = pkgs.writeText "ghostty-overlays-${mode}.css" (
      paint mode (builtins.readFile ./ghostty-overlays.css)
    );
    "kvantum.kvconfig" = pkgs.writeText "kvantum-${mode}.kvconfig" ''
      [General]
      theme=catppuccin-${if mode == "light" then "latte" else "mocha"}-mauve
    '';
  });
  assets = pkgs.linkFarm "desktop-appearance-assets" (
    lib.concatMap
      (
        mode:
        lib.mapAttrsToList (name: path: {
          name = "${mode}/${name}";
          inherit path;
        }) (palettes.${mode} // config.my.desktop.appearance.files.${mode})
      )
      [
        "light"
        "dark"
      ]
  );
  emacsTheme = (pkgs.emacsPackagesFor hm.programs.emacs.package).catppuccin-theme;
  emacsThemeDir = pkgs.runCommand "catppuccin-elisp-source" { } ''
    src=$(find ${emacsTheme}/share/emacs -name catppuccin-theme.el -print -quit)
    test -n "$src"
    mkdir "$out"
    for name in catppuccin-theme.el catppuccin-definitions.el; do
      test -f "$(dirname "$src")/$name"
      ln -s "$(dirname "$src")/$name" "$out/$name"
    done
  '';
  emacsIntegration = pkgs.writeText "appearance-emacs.el" (
    builtins.replaceStrings [ "@STATE@" "@THEME_DIR@" ] (map builtins.toJSON [
      "${root}/current"
      "${emacsThemeDir}"
    ]) (builtins.readFile ./appearance-emacs.el)
  );
  cli = pkgs.writeShellApplication {
    name = "keke-appearance";
    runtimeInputs = [
      pkgs.glib
      pkgs.niri
      pkgs.systemd
      hm.programs.emacs.finalPackage
    ];
    text = ''
      export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      exec ${pkgs.python3}/bin/python3 ${./appearance.py} --root ${lib.escapeShellArg root} --assets ${assets} \
        --emacs-init ${emacsIntegration} --fcitx-config ${lib.escapeShellArg "${hm.xdg.configHome}/fcitx5/conf/classicui.conf"} "$@"
    '';
  };
in
{
  my.desktop.appearance = {
    inherit root;
    command = lib.getExe cli;
  };
  system.build.desktopAppearance = cli;
  myuser.hm = {
    home.file.".local/bin/keke-appearance".source = lib.getExe cli;
    programs.ghostty.settings.gtk-custom-css = [ "${root}/current/ghostty-overlays.css" ];
    # Reload just the config of an existing GTK app when a generation changes
    # it. Normal palette changes are handled by Ghostty's GTK color-scheme
    # signal and don't need a reload (or an extra toast).
    home.activation.reloadGhosttyAppearance = inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if ! ${lib.getExe' pkgs.diffutils "cmp"} -s \
        "''${oldGenPath:-/nonexistent}/home-files/.config/ghostty/config" \
        "$newGenPath/home-files/.config/ghostty/config"; then
        run ${pkgs.writeShellScript "reload-ghostty-config-if-running" ''
          busctl=${lib.getExe' pkgs.systemd "busctl"}
          app=com.mitchellh.ghostty
          owner=$("$busctl" --user call org.freedesktop.DBus /org/freedesktop/DBus \
            org.freedesktop.DBus NameHasOwner s "$app" 2>/dev/null) || exit 0
          [[ "$owner" == 'b true' ]] || exit 0
          "$busctl" --user --auto-start=no --timeout=4s call "$app" /com/mitchellh/ghostty \
            org.gtk.Actions Activate 'sava{sv}' reload-config 0 0 \
            || echo 'Ghostty config installed; the running window has not reloaded it yet.' >&2
        ''}
      fi
    '';
    home.activation.seedAppearance =
      inputs.home-manager.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
        ''
          run ${lib.getExe cli} prepare
        '';
    systemd.user.services.desktop-appearance = {
      Unit = {
        Description = "Apply the Linux desktop appearance";
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cli} reconcile";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    systemd.user.timers.desktop-appearance = {
      Unit = {
        Description = "Reconcile appearance at local time boundaries";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnCalendar = [
          "*-*-* 07:00:00"
          "*-*-* 18:00:00"
        ];
        OnClockChange = true;
        OnTimezoneChange = true;
        Persistent = true;
        AccuracySec = "1s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    programs.emacs.extraConfig = ''
      (declare-function flakes-appearance-apply ${builtins.toJSON (toString emacsIntegration)})
      (load ${builtins.toJSON (toString emacsIntegration)} nil 'nomessage)
      (flakes-appearance-apply)
    '';
  };
}
