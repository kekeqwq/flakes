{ pkgs, ... }:
{
  # GUI/tools used on both macOS and NixOS. Import this from both hosts.
  # Do not also list these in environment.systemPackages: on Darwin that
  # creates a second .app under /Applications/Nix Apps.
  myuser.hm.xdg.configFile."mpv/mpv.conf".text = ''
    save-position-on-quit
    volume-max=300
  '';

  environment.systemPackages = with pkgs; [
    mpv
    scrcpy
    # Builds Spotify, then applies SpotX. No existing install is required.
    spotify-spotx
  ];
}
