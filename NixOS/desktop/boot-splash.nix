{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaper = import ./wallpaper-runtime.nix { inherit config pkgs lib; };
  plymouth = lib.getExe' config.boot.plymouth.package "plymouth";
  setlogcons = lib.getExe' pkgs.kbd "setlogcons";
in
{
  # Linux desktop policy only. No dataset names, passwords or machine-specific
  # DRM drivers live here. Native ZFS and LUKS both use Plymouth's ask agent.
  boot.plymouth = {
    enable = true;
    theme = "keke";
    themePackages = [
      (pkgs.callPackage ../../pkgs/keke-plymouth { wallpaper = wallpaper.default; })
    ];
  };
  environment.systemPackages = [ wallpaper.ctl ];
  system.boot.extraInitrd.paths = lib.optional config.boot.loader.systemd-boot.enable wallpaper.archiveName;
  boot.loader.systemd-boot.extraInstallCommands = wallpaper.seedBoot;
  # Fresh installs start in default mode. A later switch must not rotate: the
  # user's mode and image survive every rebuild until they change them.
  system.activationScripts.seedWallpaper = {
    deps = [ "users" ];
    text = ''
      if [ ! -f ${wallpaper.current} ]; then
        ${lib.getExe wallpaper.rotate} seed
      fi
    '';
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

  systemd.services = {
    plymouth-quit.serviceConfig.ExecStart = [
      ""
      "-${plymouth} quit --retain-splash"
    ];

    # Keep the retained splash while greetd hands DRM to the desktop.
    greetd = lib.mkIf config.services.greetd.enable {
      serviceConfig = {
        Type = lib.mkForce "simple";
        StandardOutput = lib.mkForce "journal";
        StandardError = lib.mkForce "journal";
        TTYReset = lib.mkForce false;
        TTYVTDisallocate = lib.mkForce false;
      };
    };
  }
  // lib.genAttrs [ "plymouth-halt" "plymouth-poweroff" "plymouth-reboot" ] (_: {
    # Stopping the display manager alone does not stop the user's compositor.
    after = [ "systemd-logind.service" ];
    # Keep late printk (including after systemd-shutdown raises its log level)
    # off the splash. Logs still go to kmsg; /dev/console and watchdog policy
    # are unchanged. A system without VTs can still shut down normally.
    serviceConfig.ExecStartPre = "-${setlogcons} --console=/dev/tty63 63";
  });
}
