{
  config,
  pkgs,
  lib,
}:
let
  user = config.myuser.name;
  home = config.users.users.${user}.home;
  default = import ./wallpaper.nix;
  stateDir = "/var/lib/keke-plymouth";
  current = "${stateDir}/wallpaper.png";
  # A source record exists only for a tracked, individually selected image.
  sourceState = "${stateDir}/current-source";
  boot = config.boot.loader.systemd-boot;
  bootMount =
    if boot.xbootldrMountPoint != null then
      boot.xbootldrMountPoint
    else
      config.boot.loader.efi.efiSysMountPoint;
  archiveName = "keke-wallpaper.cpio";
  archive = "${bootMount}/${archiveName}";
  # Denali boots a composed UKI rather than a type-1 entry with an external
  # initrd. The EFI stub reads this data file fresh on every boot.
  useStubWallpaper = config.surface.devices.denali.enable or false;
  bootWallpaper = "${bootMount}/loader/credentials/keke-wallpaper.png.cred";
  installBootWallpaper = ''
    ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg bootMount}
    ${pkgs.coreutils}/bin/install -d -m0700 ${lib.escapeShellArg (builtins.dirOf bootWallpaper)}
    staged=$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${bootWallpaper}.XXXXXXXX"})
    if ${pkgs.coreutils}/bin/install -m0600 "$image" "$staged" &&
       ${pkgs.coreutils}/bin/mv -fT -- "$staged" ${lib.escapeShellArg bootWallpaper}; then
      ${pkgs.coreutils}/bin/sync -f ${lib.escapeShellArg bootMount}
    else
      ${pkgs.coreutils}/bin/rm -f -- "$staged"
      exit 1
    fi
  '';
  python = pkgs.python3.withPackages (p: [ p.pillow ]);
  asUser = "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} --";
  select = pkgs.writeShellScript "wallpaper-selection" ''
    exec ${python}/bin/python3 -I ${./wallpaper-select.py} "$@"
  '';
  slideHelper = pkgs.writeShellScript "wallpaper-lock-slide" ''
    exec ${pkgs.coreutils}/bin/timeout --kill-after=1 4 ${select} slide \
      ${lib.escapeShellArg home} ${lib.escapeShellArg current} "$1"
  '';
  slideEnv = ''
    unset KEKE_LOCK_SLIDE_HELPER KEKE_LOCK_SLIDE_MODE
    if [ "$image" = ${lib.escapeShellArg current} ] &&
       mode=$(${select} mode "$snapshot" ${lib.escapeShellArg sourceState} 2>/dev/null); then
      export KEKE_LOCK_SLIDE_HELPER=${slideHelper} KEKE_LOCK_SLIDE_MODE="$mode"
    fi
  '';
  # Only a single root-staged, normalized PNG enters the extra initrd. Keep
  # the previous boot file on any failure, and never write to an unmounted ESP.
  pack = import ./wallpaper-initrd.nix { inherit pkgs; };
  packCurrent = ''
    ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg bootMount}
    ${lib.getExe pack} "$image" ${lib.escapeShellArg archive}
  '';
  # A fresh install has no image yet and starts in default mode. Later
  # switches deliberately leave both the image and the mode untouched.
  seedBoot = ''
    image=${lib.escapeShellArg "${default}"}
    if [ -s ${current} ]; then
      image=${current}
    fi
    ${lib.optionalString useStubWallpaper installBootWallpaper}
    if [ ! -s ${lib.escapeShellArg archive} ]; then
      ${packCurrent}
    fi
  '';
  rotate = pkgs.writeShellApplication {
    name = "wallpaper-system";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      [ "$#" -eq 1 ] && [ "$EUID" -eq 0 ] || exit 2
      if [ "$1" != seed ]; then
        # Printed only after sudo's own authentication has already succeeded.
        printf '%s\n' '[keke-sudo-authorized]' >&2
      fi
      umask 077
      install -d -m 0755 ${stateDir}
      exec 9>${stateDir}/selection.lock
      flock -w 20 9
      # Stage replacements on the same filesystem as the live snapshot.
      work=$(mktemp -d ${stateDir}/.selection.XXXXXXXX)
      trap 'rm -rf -- "$work"' EXIT
      image="$work/wallpaper.png"
      metadata="$work/source"

      pick() {
        # Decode as the desktop user. The shell opens the packet and old
        # metadata before runuser; the user cannot access the staging dir.
        (ulimit -f 131080; timeout 30 ${asUser} ${select} pick \
          ${lib.escapeShellArg home} ${lib.escapeShellArg "${default}"} ${lib.escapeShellArg current} "$1" 9>&-) > "$work/packet" || return
        ${select} unpack "$work/packet" "$image" "$metadata"
      }

      install_image() {
        chmod 0644 "$image"
        if [ "$1" != seed ]; then
          ${if boot.enable then packCurrent else ":"}
          ${lib.optionalString (boot.enable && useStubWallpaper) installBootWallpaper}
        fi
        mv -fT -- "$image" ${lib.escapeShellArg current}
        if [ -s "$metadata" ]; then
          chmod 0644 "$metadata"
          mv -fT -- "$metadata" ${lib.escapeShellArg sourceState}
        else
          rm -f -- ${lib.escapeShellArg sourceState}
        fi
      }

      case "$1" in
        seed|default)
          if [ "$1" = seed ] && [ -f ${lib.escapeShellArg current} ]; then exit 0; fi
          install -m644 ${lib.escapeShellArg "${default}"} "$image"
          install_image "$1"
          ;;
        random|sfw)
          if ! pick "$1" < /dev/null; then
            install -m644 ${lib.escapeShellArg "${default}"} "$image"
            : > "$metadata"
          fi
          install_image "$1"
          ;;
        delete)
          if [ ! -s ${lib.escapeShellArg sourceState} ]; then
            echo 'No tracked wallpaper source to delete.' >&2
            exit 3
          fi
          ${select} require-current ${lib.escapeShellArg current} ${lib.escapeShellArg sourceState}
          cp -- ${lib.escapeShellArg sourceState} "$work/previous"
          pick delete < "$work/previous"
          install_image delete
          # Never unlink a home-directory path with root privileges.
          timeout 10 ${asUser} ${select} unlink ${lib.escapeShellArg home} 9>&- < "$work/previous" || exit 5
          ;;
        *) exit 2 ;;
      esac
    '';
  };
  refresh = pkgs.writeShellScript "wallpaper-refresh-session" ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active wallpaper.service; then
      ${pkgs.systemd}/bin/systemctl --user --no-block try-restart wallpaper.service
    fi
  '';
  ctl = pkgs.writeShellScriptBin "wallpaper-ctl" ''
    set -eu
    case "''${1:-}" in
      status)
        ${select} mode ${lib.escapeShellArg current} ${lib.escapeShellArg sourceState} 2>/dev/null || printf 'default\n'
        exit 0
        ;;
      random|sfw|default|delete) ;;
      *) exit 2 ;;
    esac
    rc=0
    /run/wrappers/bin/sudo -k -S -p '[keke-sudo-password]' -- ${lib.getExe rotate} "$1" || rc=$?
    # Exit 5 means the image switched, but removing the previous file failed.
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 5 ]; then ${refresh}; fi
    exit "$rc"
  '';
in
{
  inherit
    default
    current
    sourceState
    rotate
    ctl
    refresh
    archiveName
    seedBoot
    slideEnv
    ;
  packInitrd = pack;
  resolve = ''
    image=${lib.escapeShellArg "${default}"}
    if [ -r ${current} ]; then
      image=${current}
    fi
  '';
}
