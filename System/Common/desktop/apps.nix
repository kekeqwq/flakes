{
  lib,
  pkgs,
  ...
}:
{
  # GUI/tools used on both macOS and NixOS. Import this from both hosts.
  # Do not also list these in environment.systemPackages: on Darwin that
  # creates a second .app under /Applications/Nix Apps.
  myuser.hm.xdg.configFile."mpv/mpv.conf".text = ''
    save-position-on-quit
    volume-max=300
    stop-screensaver=yes
  '';

  environment.systemPackages =
    with pkgs;
    [
      mpv
      scrcpy
    ]
    # Match SpotX-Nix's supported platforms exactly. In particular, ARM Linux
    # must not evaluate the Spotify package or pull it into the system closure.
    ++
      lib.optionals
        (builtins.elem stdenv.hostPlatform.system [
          "aarch64-darwin"
          "x86_64-linux"
        ])
        [
          (spotify-spotx.override {
            # SpotX applies its free-tier patches by default. --premium skips them.
            spotxArgs = [
              "--hide"
            ]
            ++ lib.optionals stdenv.hostPlatform.isDarwin [
              # Prevent Spotify's macOS updater from replacing the Nix-built app.
              "--blockupdates"
            ];
          })
        ];
}
