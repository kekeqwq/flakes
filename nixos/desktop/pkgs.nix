{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    cataclysm-dda-git
    firefox
    # prismlauncher
    tdesktop
  ];
  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs-head;
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
