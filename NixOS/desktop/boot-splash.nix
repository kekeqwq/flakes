{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.myuser.name;
  wallpaper = import ./wallpaper-runtime.nix { inherit config pkgs lib; };
  asUser = "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} --";

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
  environment.systemPackages = [ wallpaper.random ];
  system.boot.extraInitrd.paths = lib.optional config.boot.loader.systemd-boot.enable wallpaper.archiveName;
  boot.loader.systemd-boot.extraInstallCommands = wallpaper.seedBoot;
  system.activationScripts.randomWallpaper = {
    deps = [ "users" ];
    text = ''
      if [ "''${NIXOS_ACTION:-}" = switch ]; then
        if ${lib.getExe wallpaper.rotate}; then
          uid=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg user})
          if [ -S "/run/user/$uid/bus" ]; then
            ${asUser} ${pkgs.coreutils}/bin/env XDG_RUNTIME_DIR="/run/user/$uid" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" ${wallpaper.refresh} || true
          fi
        else
          echo 'Wallpaper selection failed; leaving the current image in place.' >&2
        fi
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
