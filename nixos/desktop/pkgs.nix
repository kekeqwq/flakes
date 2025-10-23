{ pkgs, config, ... }:
{
  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs30-pgtk;
  };
  programs.adb.enable = true;
  myuser.users = {
    extraGroups = [
      "adbusers"
      "dialout"
    ];
  };
  services.udev.packages = with pkgs; [
    via
    android-udev-rules
    yubikey-personalization
  ];
  services.udev.extraRules = ''
    # Touch Lite
    SUBSYSTEM=="usb", ATTR{idVendor}=="109b", ATTR{idProduct}=="911f", MODE="0666", GROUP="adbusers"
    # Espressif USB Serial/JTAG Controller
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0660", TAG+="uaccess"
  '';

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
    snipaste
    discord
    mpv
    wayvnc
    spotify
    firefox
    prismlauncher
    tdesktop
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
