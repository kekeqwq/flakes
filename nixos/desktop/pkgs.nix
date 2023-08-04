{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    cataclysm-dda-git
    firefox
    prismlauncher
    tdesktop
    pinentry-curses
  ];

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
