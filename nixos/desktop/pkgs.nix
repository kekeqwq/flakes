{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    cataclysm-dda-git
    firefox-bin
    prismlauncher
    tdesktop
    pinentry-curses
  ];
  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs29-pgtk;
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
