{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ../../NixOS/desktop/baseline.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "secret-lab";
  networking.hostId = "5ec04ab1";
  system.stateVersion = "26.11";

  # One LUKS2 container protects all Btrfs subvolumes. Use the standard
  # systemd/Plymouth FIDO2 integration, with a separately retained password.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  my.luks = {
    enable = true;
    name = "cryptroot";
    device = "/dev/disk/by-partlabel/secret-lab-cryptroot";
    fido2.enable = true;
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/SECRETEFI";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=@root"
        "compress=zstd:3"
        "noatime"
      ];
    };
    "/nix" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd:3"
        "noatime"
      ];
    };
    "/home" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:3"
        "noatime"
      ];
    };
  };
  # No unencrypted swap or hibernation image in this fresh regression guest.
  swapDevices = [ ];
  boot.kernelParams = [ "nohibernate" ];
  networking.firewall.enable = true;
  # Private virtio/Unix management channel, available only after root unlock.
  services.qemuGuest.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  my.desktop.niri.outputs = ''
    output "Virtual-1" {
        mode "1920x1080@60.000"
        scale 1
        transform "normal"
        position x=0 y=0
    }
  '';

  # View QEMU directly in a Deck desktop window. No guest streaming/pairing.
  my.sunshine.enable = false;
}
