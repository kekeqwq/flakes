{ pkgs, config, ... }: {

  environment.systemPackages = with pkgs; [
    cataclysm-dda-git
    firefox
    prismlauncher
    tdesktop
    pinentry-curses
  ];

  #Sing-box
  systemd.services.sing-box = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "nss-lookup.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.sing-box}/bin/sing-box run --config /home/${config.myuser.name}/.config/sing-box/config.json";
      ExecReload = "/run/current-system/sw/bin/pkill sing-box";
      WorkingDirectory = "/home/${config.myuser.name}/.config/sing-box";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # GPG
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
