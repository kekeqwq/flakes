{ config, pkgs, ... }:

{
  # Core
  jovian.devices.steamdeck.enable = true;
  programs.steam.enable = true;
  boot.zfs.devNodes = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQD-1T00_230255456613-part2";
  ## If only one sensitive zvol is encrypted, then this option prevents automatic decryption on boot.
  boot.zfs.requestEncryptionCredentials = false;

  # Network
  networking.hostName = "deck";
  networking.hostId = "00bab10d";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  myuser.name = "keke";
  myuser.users = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
  };
  services = {
    logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandlePowerKeyLongPress = "suspend";
    };
  };

  myuser.hm.programs.fish = {
    interactiveShellInit = ''
      set -Ux WLR_BACKENDS headless
      set -Ux WLR_LIBINPUT_NO_DEVICES 1
      set -Ux WAYLAND_DISPLAY wayland-1
      set -Ux WLR_RENDER_DRM_DEVICE /dev/dri/card0
    '';
  };

  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "${config.myuser.name}";
    desktopSession = "niri";
  };

  #TODO: fix sound issue in minimal system
  environment.pathsToLink = [ "/share/alsa/ucm2" ];

  myuser.hm.home.stateVersion = "24.11";
  system.stateVersion = "24.11";
}
