{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.controlCenter;
  wallpaper = import ./wallpaper-runtime.nix { inherit config pkgs lib; };
  actionType = lib.types.submodule {
    options = {
      id = lib.mkOption { type = lib.types.strMatching "[a-z][a-z0-9-]*"; };
      label = lib.mkOption { type = lib.types.str; };
      icon = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      argv = lib.mkOption { type = lib.types.listOf lib.types.str; };
      confirm = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      confirm_message = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      # "sudo" renders this action through the inline authorization view.
      auth = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "sudo" ]);
        default = null;
      };
      # The button stays disabled while this file is empty or missing.
      requires_nonempty_file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };
  common = import ./control-center-actions.nix { inherit pkgs wallpaper; };
  # Use the graphical user manager's environment, not GTK's app wrapper env.
  appearanceFromPanel = pkgs.writeShellScript "keke-appearance-from-panel" ''
    exec ${lib.getExe' pkgs.systemd "systemd-run"} --user --wait --pipe --collect --quiet -- \
      ${lib.escapeShellArg config.my.desktop.appearance.command} "$@"
  '';
  actions = pkgs.writeText "control-center-actions.json" (
    builtins.toJSON {
      inherit common;
      private = cfg.extraActions;
      appearance = appearanceFromPanel;
    }
  );
in
{
  options.my.desktop.controlCenter.extraActions = lib.mkOption {
    type = lib.types.listOf actionType;
    default = [ ];
    description = "Instance-private control-center actions, appended below shared power/lock actions. Commands are argv vectors, never shell snippets.";
  };
  config = lib.mkIf config.my.desktop.enable {
    assertions = [
      {
        assertion =
          lib.all (a: a.argv != [ ]) cfg.extraActions
          &&
            lib.length (lib.unique (map (a: a.id) (common ++ cfg.extraActions)))
            == lib.length (common ++ cfg.extraActions);
        message = "Control-center action IDs must be unique and commands nonempty.";
      }
    ];
    myuser.hm.xdg.configFile."keke-waybar-panel/actions.json".source = actions;
  };
}
