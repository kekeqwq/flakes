{ config, pkgs, ... }:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  services.openssh.enable = true;

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Asia/Shanghai";

  myuser.hm.programs.fish.enable = true;
}

