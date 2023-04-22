{ config, pkgs, ... }:

{
  # Core
  jovian.devices.steamdeck.enable = true;
  jovian.steam.enable = true;
  programs.steam.enable = true;

  # Network
  networking.hostName = "deck";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;


  myuser.name = "keke";
  myuser.users = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Base
  environment.systemPackages = with pkgs; [
    compsize
    cemu
  ];

  # WIP:fix sddm
  # services.xserver.displayManager.setupCommands =
  #   "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate right";

  myuser.hm.home.stateVersion = "23.05";
  system.stateVersion = "23.05";
}

