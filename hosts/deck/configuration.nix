{ config, pkgs, ... }:

{
  # Core
  jovian.devices.steamdeck.enable = true;
  programs.steam.enable = true;
  boot.zfs.devNodes = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQD-1T00_230255456613-part2";
  ## If only one sensitive zvol is encrypted, then this option prevents automatic decryption on boot.
  boot.zfs.requestEncryptionCredentials = false;
  boot.zfs.forceImportRoot = false;

  # Network
  networking.hostName = "deck";
  networking.hostId = "00bab10d";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  virtualisation.docker.enable = true;

  myuser.name = "keke";
  myuser.users = {
    isNormalUser = true;
    extraGroups = [
      "docker"
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

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."usb-wifi-proxy" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8181;
        }
      ];

      locations."/" = {
        proxyPass = "http://192.168.1.1";

        extraConfig = ''
          # 伪装 Host，绕过随身 Wi-Fi 的安全检查
          proxy_set_header Host "192.168.1.1";
          proxy_set_header Referer "http://192.168.1.1/";

          # 确保 Cookie 和 Session 在转发时不会因为域名/IP不匹配而丢失
          proxy_cookie_domain 192.168.1.1 $host;
          proxy_cookie_path / /;

          # 禁用缓存，防止浏览器缓存旧的短信列表
          proxy_buffering off;
          add_header Cache-Control "no-cache, no-store, must-revalidate";
        '';
      };
    };
  };

  myuser.hm.home.stateVersion = "24.11";
  system.stateVersion = "24.11";
}
