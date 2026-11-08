{ config, lib, ... }:
{
  options.my.desktop = {
    niri.extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific Niri configuration prepended to the shared desktop configuration.";
    };
  };

  # Linux-only graphical configuration. Common/desktop is gated by the same
  # switch, independently of this Linux layer.
  imports =
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
        ./emacs-rime.nix
        ./wayland.nix
        ./sunshine.nix
        ./yazi.nix
      ];
}
