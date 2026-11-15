{ lib, pkgs, ... }:
let
  pin = import ./pin-clipboard.nix { inherit pkgs; };
in
{
  # XWayland is required by the proprietary Linux build. Capturing native
  # Wayland windows is handled by Niri's clipboard-only screenshot bindings.
  myuser.hm.home.packages = lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ pin ];
  myuser.hm.systemd.user.services.snipaste = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    Unit = {
      Description = "Snipaste tray and clipboard pinning";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe pkgs.snipaste;
      Environment = [
        "QT_QPA_PLATFORM=xcb"
        "QT_STYLE_OVERRIDE=Fusion"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
