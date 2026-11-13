{ config, lib, ... }:
{
  options.my.desktop = {
    niri.outputs = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific Niri output/display configuration. Every instance has different monitors, so only that host sets modes, scale and positions.";
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
        ./fonts.nix
        ./theme.nix
        ./pkgs.nix
        ./input-method.nix
        ./mimeapps.nix
        ./emacs-rime.nix
        ./wayland.nix
        ./yazi.nix
      ];
}
