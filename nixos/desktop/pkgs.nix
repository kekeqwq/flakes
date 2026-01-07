{
  pkgs,
  config,
  inputs,
  ...
}:
let
  firefoxFlake = inputs.firefox.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.weylus = {
    enable = true;
    users = [ "keke" ];
  };

  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs30-pgtk;
  };

  services.udev.packages = with pkgs; [
    via
    yubikey-personalization
  ];

  # Fcitx5
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      # waylandFrontend = true;
      addons = with pkgs; [
        catppuccin-fcitx5
        (fcitx5-rime.override {
          rimeDataPkgs = with pkgs; [
            rime-ice
          ];
        })
      ];
    };
  };
  environment.systemPackages = with pkgs; [
    usbutils
    f2fs-tools
    firefoxFlake.firefox-nightly-bin
    qbittorrent
    discord
    mpv
    spotify
    prismlauncher
    telegram-desktop
    pinentry-curses
    scrcpy
  ];

  #Sing-box
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

  # GPG
  services.pcscd.enable = true;
  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
