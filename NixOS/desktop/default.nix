{ config, lib, ... }:
{
  options.my.desktop = {
    battery.device = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[A-Za-z0-9_-]+");
      default = null;
      description = "Power-supply name to use in Waybar and the lock screen. Null keeps automatic multi-battery reporting.";
    };
    appearance = {
      root = lib.mkOption {
        type = lib.types.str;
        internal = true;
      };
      command = lib.mkOption {
        type = lib.types.str;
        internal = true;
      };
      files = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.path);
        internal = true;
      };
    };
    niri.outputs = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific Niri output/display configuration. Every instance has different monitors, so only that host sets modes, scale and positions.";
    };
    niri.touchOutput = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Output name for a host's touchscreen; null retains Niri's default mapping.";
    };
    niri.extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Other host-specific Niri configuration prepended to the shared desktop configuration. Displays belong in niri.outputs.";
    };
  };

  # Linux-only graphical configuration. Common/desktop is gated by the same
  # switch, independently of this Linux layer. Host-varying features are
  # options in this folder, default off; hosts only set the differences.
  imports = [
    ./sunshine.nix
    ./control-center.nix
  ]
  ++
    map
      (
        path:
        {
          config,
          lib,
          pkgs,
          inputs,
          ...
        }@args:
        {
          _file = toString path;
          config = lib.mkIf config.my.desktop.enable (import path args);
        }
      )
      [
        ./session.nix
        ./boot-splash.nix
        ./fonts.nix
        ./theme.nix
        ./appearance.nix
        ./pkgs.nix
        ./input-method.nix
        ./mimeapps.nix
        ./emacs-rime.nix
        ./emacs-client.nix
        ./wayland.nix
        ./lock-screen.nix
        ./snipaste.nix
        ./yazi.nix
      ];
}
