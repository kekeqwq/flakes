{ lib, ... }:
{
  imports = [
    ../../System/Common
    ./sys.nix
    ./services.nix
    ./qbittorrent.nix
    ./luks.nix
  ];

  # Linux-specific, non-graphical account defaults. Shell/editor/Git/Pi and
  # other portable terminal tools come from System/Common above.
  myuser.users = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  myuser.hm.home.stateVersion = lib.mkDefault "24.11";
}
