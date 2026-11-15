{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Linux desktop policy only. No dataset names, passwords or machine-specific
  # DRM drivers live here. Native ZFS and LUKS both use Plymouth's ask agent.
  boot.plymouth = {
    enable = true;
    theme = "keke";
    themePackages = [
      (pkgs.callPackage ../../pkgs/keke-plymouth { wallpaper = import ./wallpaper.nix; })
    ];
  };
  boot.consoleLogLevel = 0;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
    "rd.systemd.show_status=auto"
    "vt.global_cursor_default=0"
  ];
  # Space at power-on still opens systemd-boot's recovery/generation menu.
  boot.loader.timeout = lib.mkDefault 0;

  # Do not clear the retained splash or print a greeter/daemon log on VT1 while
  # an ordinary autologin desktop takes over DRM. Deck uses Jovian, not greetd.
  systemd.services.greetd = lib.mkIf config.services.greetd.enable {
    serviceConfig = {
      Type = lib.mkForce "simple";
      StandardOutput = lib.mkForce "journal";
      StandardError = lib.mkForce "journal";
      TTYReset = lib.mkForce false;
      TTYVTDisallocate = lib.mkForce false;
    };
  };
}
