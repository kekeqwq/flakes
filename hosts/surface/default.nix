{ config, inputs, ... }:
{
  imports = [
    ../../NixOS/desktop/baseline.nix
    inputs.surface.nixosModules.default
  ];

  networking.hostName = "surface";
  system.stateVersion = "26.05";

  surface.devices.denali = {
    enable = true;
    privateFirmwareDirectory = "/var/lib/surface-firmware";
  };
  my.desktop.niri.outputs = config.surface.devices.denali.niriOutputs;

  # Preserve the existing native deployment. Disk migration is separate.
  my.luks.enable = false;
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS_EFI";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
  swapDevices = [ ];
  boot.loader.timeout = 5;
  my.sunshine.enable = false;

  users.mutableUsers = true;
  services.openssh.authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };
}
