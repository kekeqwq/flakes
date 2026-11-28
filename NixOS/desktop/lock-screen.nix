{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaper = import ./wallpaper-runtime.nix { inherit config pkgs lib; };
  lock = pkgs.writeShellApplication {
    name = "screen-lock";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.swaylock-security-key
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?A graphical user session is required}"
      umask 077
      # The daemon inherits FD 9 and keeps the singleton lock until unlock.
      exec 9>"$XDG_RUNTIME_DIR/screen-lock.lock"
      if ! flock --nonblock 9; then exit 0; fi
      # Returns only once the compositor has secured the screen, also before
      # sleep. The atomic marker records acquisition, not ongoing lock status.
      ${wallpaper.resolve}
      snapshot=$(mktemp "$XDG_RUNTIME_DIR/screen-lock-image.XXXXXXXX")
      trap 'rm -f -- "$snapshot"' EXIT
      cp -- "$image" "$snapshot"
      ${wallpaper.slideEnv}
      appearance=$(readlink ${lib.escapeShellArg "${config.my.desktop.appearance.root}/current"} || :)
      colors=()
      if [[ ''${appearance##*/} == light ]]; then
        # Contrast against any wallpaper without altering the secure lock or
        # the selected wallpaper itself. An existing lock is never restarted.
        colors=(
          --color eff1f5 --inside-color eff1f5ee --inside-clear-color eff1f5ee
          --inside-ver-color eff1f5ee --inside-wrong-color eff1f5ee
          --text-color 4c4f69 --text-clear-color 4c4f69
          --text-ver-color 8839ef --text-wrong-color d20f39
          --ring-ver-color 8839ef --ring-wrong-color d20f39
          --key-hl-color df8e1d --bs-hl-color d20f39
        )
      fi
      swaylock "''${colors[@]}" --image "$snapshot" --daemonize
      ready="$XDG_RUNTIME_DIR/screen-lock.ready"
      printf '%s\n' "$$" > "$ready.$$"
      mv -f "$ready.$$" "$ready"
    '';
  };
in
{
  services.logind.settings.Login = {
    # Niri binds the power key to screen-lock. Do not also power off or sleep
    # from logind, including a long press detected by logind (not firmware).
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
    # logind sends the session Lock event; swayidle below owns the locker.
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

  # Password authentication must never wait behind the hardware-key attempt.
  security.pam.services.swaylock.u2f.enable = false;
  # A separate strict stack for the locker's private background worker. No
  # password fallback and no permissive/missing-user success in this service.
  security.pam.services.swaylock-key.text = ''
    auth required ${pkgs.pam_u2f}/lib/security/pam_u2f.so authfile=${config.security.pam.u2f.settings.authfile} origin=${config.security.pam.u2f.settings.origin} appid=${config.security.pam.u2f.settings.origin} userpresence=1 pinverification=0 userverification=0
    account required ${pkgs.pam}/lib/security/pam_unix.so
  '';
  myuser.hm = {
    home.packages = [ lock ];
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-security-key;
      settings = {
        # Path interpolation copies the tracked PNG into the store and retains
        # its dependency context. toString alone can leave a dangling source path.
        image = "${wallpaper.default}";
        scaling = "fill";
        color = "1e1e2e";
        font = "sans-serif";
        font-size = 140;
        clock = true;
        timestr = "%H:%M";
        datestr = "%Y-%m-%d";
        indicator = true;
        indicator-idle-visible = true;
        indicator-radius = 240;
        indicator-thickness = 4;
        ignore-empty-password = true;
        show-failed-attempts = true;
        inside-color = "00000000";
        inside-clear-color = "00000000";
        inside-ver-color = "00000000";
        inside-wrong-color = "00000000";
        ring-color = "00000000";
        ring-clear-color = "00000000";
        ring-ver-color = "cba6f7ff";
        ring-wrong-color = "f38ba8ff";
        line-color = "00000000";
        line-clear-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";
        separator-color = "00000000";
        text-color = "cdd6f4ff";
        text-clear-color = "cdd6f4ff";
        text-ver-color = "cba6f7ff";
        text-wrong-color = "f38ba8ff";
        key-hl-color = "f5c2e7ff";
        bs-hl-color = "f38ba8ff";
      };
    };
    # Deck also offers a Gamescope session; do not run the Niri idle policy there.
    systemd.user.services.swayidle.Unit.ConditionEnvironment = lib.mkForce [
      "WAYLAND_DISPLAY"
      "XDG_CURRENT_DESKTOP=niri"
    ];
    services.swayidle = {
      enable = true;
      # Native seat input and compositor idle inhibitors, not pointer polling:
      # typing counts as activity; a playing video can inhibit idle in a window
      # or fullscreen. Do not use an input-only/ignore-inhibitors mode.
      timeouts = [
        {
          timeout = 300;
          command = "${lock}/bin/screen-lock";
        }
      ];
      events = {
        before-sleep = "${lock}/bin/screen-lock";
        lock = "${lock}/bin/screen-lock";
      };
    };
  };
}
