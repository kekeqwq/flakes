{
  config,
  pkgs,
  lib,
}:
let
  user = config.myuser.name;
  home = config.users.users.${user}.home;
  default = import ./wallpaper.nix;
  current = "/var/lib/keke-plymouth/wallpaper.png";
  boot = config.boot.loader.systemd-boot;
  bootMount =
    if boot.xbootldrMountPoint != null then
      boot.xbootldrMountPoint
    else
      config.boot.loader.efi.efiSysMountPoint;
  archiveName = "keke-wallpaper.cpio";
  archive = "${bootMount}/${archiveName}";
  python = pkgs.python3.withPackages (p: [ p.pillow ]);
  asUser = "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} --";
  select = pkgs.writeShellScript "wallpaper-selection" ''
    exec ${python}/bin/python3 -I ${./wallpaper-select.py} ${
      lib.escapeShellArgs [
        home
        "${default}"
        current
      ]
    }
  '';
  # Only a single root-staged, normalized PNG enters the extra initrd. Keep
  # the previous boot file on any failure, and never write to an unmounted ESP.
  pack = import ./wallpaper-initrd.nix { inherit pkgs; };
  packCommand = ''
    ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg bootMount}
    ${lib.getExe pack} "$image" ${lib.escapeShellArg archive}
  '';
  seedBoot = ''
    if [ ! -s ${lib.escapeShellArg archive} ]; then
      image=${lib.escapeShellArg "${default}"}
      ${packCommand}
    fi
  '';
  rotate = pkgs.writeShellApplication {
    name = "wallpaper-rotate-system";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      [ "$#" -eq 0 ] && [ "$EUID" -eq 0 ] || exit 2
      printf '%s\n' '[keke-sudo-authorized]' >&2
      umask 077
      install -d -m 0755 ${builtins.dirOf current}
      exec 9>${builtins.dirOf current}/selection.lock
      flock -w 20 9
      image=$(mktemp ${builtins.dirOf current}/.wallpaper.XXXXXXXX)
      trap 'rm -f -- "$image"' EXIT
      # Decode as the desktop user, not root. Close the inherited lock FD.
      (ulimit -f 65536; timeout 20 ${asUser} ${select} 9>&-) > "$image"
      [ -s "$image" ]
      chmod 0644 "$image"
      ${lib.optionalString boot.enable packCommand}
      mv -fT -- "$image" ${current}
    '';
  };
  refresh = pkgs.writeShellScript "wallpaper-refresh-session" ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active wallpaper.service; then
      ${pkgs.systemd}/bin/systemctl --user --no-block try-restart wallpaper.service
    fi
  '';
  random = pkgs.writeShellScriptBin "wallpaper-random" ''
    set -eu
    if [ "$#" -eq 1 ] && [ "$1" = --panel ]; then
      /run/wrappers/bin/sudo -k -S -p '[keke-sudo-password]' -- ${lib.getExe rotate}
    elif [ "$#" -eq 0 ]; then
      /run/wrappers/bin/sudo -- ${lib.getExe rotate}
    else
      exit 2
    fi
    exec ${refresh}
  '';
in
{
  inherit
    default
    rotate
    random
    refresh
    archiveName
    seedBoot
    ;
  packInitrd = pack;
  resolve = ''
    image=${lib.escapeShellArg "${default}"}
    if [ -r ${current} ]; then
      image=${current}
    fi
  '';
}
