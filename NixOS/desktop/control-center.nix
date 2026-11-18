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
    };
  };
  common = [
    {
      id = "lock";
      label = "Lock screen";
      icon = "󰌾";
      argv = [ "screen-lock" ];
      confirm = false;
    }
    {
      id = "wallpaper-random";
      label = "Random Switch";
      icon = "󰋩";
      argv = [
        "${wallpaper.random}/bin/wallpaper-random"
        "--panel"
      ];
      confirm = false;
    }
    {
      id = "reboot";
      label = "Restart";
      icon = "󰜉";
      argv = [
        "${pkgs.systemd}/bin/systemctl"
        "reboot"
      ];
      confirm = true;
    }
    {
      id = "poweroff";
      label = "Power off";
      icon = "󰐥";
      argv = [
        "${pkgs.systemd}/bin/systemctl"
        "poweroff"
      ];
      confirm = true;
    }
  ];
  actions = pkgs.writeText "control-center-actions.json" (
    builtins.toJSON {
      inherit common;
      private = cfg.extraActions;
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
