{
  config,
  lib,
  pkgs,
  ...
}:
{
  myuser.users = {
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "render"
      "input"
    ];
  };
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = lib.mkDefault true;
  services.udisks2.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;
  services.orca.enable = lib.mkDefault true;
  # Steam's 32-bit graphics support is x86_64-only. Deck is x86_64; an
  # aarch64 desktop still gets Niri without this package.
  programs.steam.enable = pkgs.stdenv.hostPlatform.isx86_64;
  environment.pathsToLink = [ "/share/alsa/ucm2" ];

  # Ordinary desktops boot straight into Niri. A host that enables
  # my.luks asks for the disk passphrase before this; there is no second
  # user login. Deck disables greetd and keeps its Steam session selector.
  services.greetd = {
    enable = lib.mkDefault true;
    restart = false;
    settings.initial_session = {
      command = "${pkgs.niri}/bin/niri-session";
      user = config.myuser.name;
    };
    settings.default_session = {
      command = "${pkgs.niri}/bin/niri-session";
      user = config.myuser.name;
    };
  };
}
