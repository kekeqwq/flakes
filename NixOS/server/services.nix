{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    xrock
    rkdeveloptool
    kitty.terminfo
    usbutils
    f2fs-tools
    pinentry-curses
  ];

  services.udev.packages = [ pkgs.yubikey-personalization ];

  # The optional proxy configuration and service state are private runtime data.
  systemd.services.sing-box = {
    enable = false;
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "nss-lookup.target"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.sing-box}/bin/sing-box run --config /home/${config.myuser.name}/.config/sing-box/config.json";
      ExecReload = "/run/current-system/sw/bin/pkill sing-box";
      WorkingDirectory = "/home/${config.myuser.name}/.config/sing-box";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
