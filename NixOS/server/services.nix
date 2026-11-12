{ pkgs, ... }:
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

  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
