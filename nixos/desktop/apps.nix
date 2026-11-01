{ pkgs, ... }:
{
  # GUI/tools used on both macOS and NixOS. Import this from both hosts.
  # Do not also list these in environment.systemPackages: on Darwin that
  # creates a second .app under /Applications/Nix Apps.
  environment.systemPackages = with pkgs; [
    mpv
    scrcpy
  ];
}
