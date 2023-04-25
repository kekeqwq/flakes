{ config, pkgs, ... }:

{
  # Core
  jovian.devices.steamdeck.enable = true;
  jovian.steam.enable = true;
  programs.steam.enable = true;
  boot.zfs.devNodes =
    "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQD-1T00_230255456613-part2";

  # Network
  networking.hostName = "deck";
  networking.hostId = "00bab10d";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  myuser.name = "keke";
  myuser.users = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Base
  # environment.systemPackages = with pkgs; [
  #   compsize
  #   cemu
  # ];

  # WIP:fix sddm
  # services.xserver.displayManager.setupCommands =
  #   "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate right";

  myuser.hm.home.stateVersion = "23.05";
  system.stateVersion = "23.05";
}

