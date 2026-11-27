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
  luks = config.my.luks;
  initrdSystemd = config.boot.initrd.systemd.package;
  keyWait = pkgs.writeShellApplication {
    name = "plymouth-fido2-wait";
    runtimeInputs = [ config.boot.plymouth.package initrdSystemd pkgs.coreutils ];
    text = builtins.readFile ./fido2-wait-splash.sh;
  };
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
  boot.initrd.systemd = lib.mkIf (config.boot.plymouth.enable && luks.enable && luks.fido2.enable) {
    storePaths = [
      keyWait
      plymouth
      "${initrdSystemd}/bin/journalctl"
      "${initrdSystemd}/bin/systemd-escape"
      "${pkgs.coreutils}/bin/sleep"
    ];
    services.plymouth-fido2-wait = {
      description = "Show the native FIDO2 discovery countdown in Plymouth";
      wantedBy = [ "sysinit.target" ];
      after = [ "plymouth-start.service" "systemd-journald.socket" ];
      before = [ "initrd-switch-root.target" ];
      conflicts = [ "initrd-switch-root.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe keyWait} ${lib.escapeShellArg luks.name} ${toString luks.fido2.deviceTimeoutSeconds}";
        RuntimeMaxSec = "90s";
      };
    };
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
  boot.consoleLogLevel = lib.mkIf config.boot.plymouth.enable 0;
  boot.kernelParams = lib.mkIf config.boot.plymouth.enable [
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
    "rd.systemd.show_status=auto"
    "vt.global_cursor_default=0"
  ];
  # Space at power-on still opens systemd-boot's recovery/generation menu.
  boot.loader.timeout = lib.mkDefault 0;

  systemd.services = lib.mkIf config.boot.plymouth.enable ({
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
  }));
}
