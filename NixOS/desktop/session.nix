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
  programs.steam.enable = true;
  environment.pathsToLink = [ "/share/alsa/ucm2" ];

  # Ordinary desktops need a login/session launcher without Jovian. Deck opts
  # out and uses Jovian's Steam/Niri session selector instead.
  services.greetd = {
    enable = lib.mkDefault true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user = "greeter";
    };
  };
}
