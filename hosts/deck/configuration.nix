{ config, ... }:

{
  # Avoid memory/thread exhaustion when building the desktop stack on the Deck.
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = true;
  };
  my.qbittorrent.downloadDirectory = "/var/lib/qBittorrent/downloads";

  my.desktop.enable = true;
  my.desktop.niri.extraConfig = builtins.readFile ./outputs.kdl;

  # Jovian owns the login/session launcher on this hardware.
  services.greetd.enable = false;
  jovian.devices.steamdeck.enable = true;
  boot.zfs.devNodes = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQD-1T00_230255456613-part2";
  ## If only one sensitive zvol is encrypted, then this option prevents automatic decryption on boot.
  boot.zfs.requestEncryptionCredentials = false;
  boot.zfs.forceImportRoot = false;

  # Network
  networking.hostName = "deck";
  networking.hostId = "00bab10d";
  networking.firewall.enable = false;

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

  # Proxy is on unless set false. The first web UI visit creates the account.
  my.sunshine = {
    enable = true;
    capture = "DP-1";
    settings = {
      sunshine_name = "deck";
      capture = "kms";
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD128";
      hevc_mode = 1;
      av1_mode = 1; # Vangogh has no AV1 encoder; do not probe/advertise it.
      controller = "disabled";
      stream_audio = "disabled";
      file_state = "/home/keke/.config/sunshine/sunshine_state.json";
      credentials_file = "/home/keke/.config/sunshine/sunshine_state.json";
    };
  };

  system.stateVersion = "24.11";
}
