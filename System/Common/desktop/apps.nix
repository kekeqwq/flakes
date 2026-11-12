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
  '';

  environment.systemPackages =
    with pkgs;
    [
      mpv
      scrcpy
    ]
    # SpotX has no aarch64-linux build. macOS and x86_64 Linux still get it.
    ++ lib.optionals (stdenv.hostPlatform.isDarwin || stdenv.hostPlatform.isx86_64) [
      spotify-spotx
    ];
}
