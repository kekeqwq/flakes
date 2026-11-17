{ lib, ... }:
{
  imports = [
    ../../System/Common
    ./sys.nix
    ./services.nix
    ./qbittorrent.nix
    ./luks.nix
    ./security-keys.nix
  ];

  # Linux-specific, non-graphical account defaults. Shell/editor/Git/Pi and
  # other portable terminal tools come from System/Common above.
  myuser.users = {
    isNormalUser = true;
    # Start the per-user Emacs service at boot, even before a GUI login.
    linger = true;
    extraGroups = [ "wheel" ];
  };
  myuser.hm.home.stateVersion = lib.mkDefault "24.11";
}
