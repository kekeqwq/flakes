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

  # ZFS 2.4.4 supports this LTS kernel. Do not bypass the compatibility gate
  # to follow baseline.nix's newest kernel on an encrypted-root instance.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    devNodes = "/dev/disk/by-id";
    forceImportRoot = false;
    # One encryption root, one graphical question, all children inherit its key.
    requestEncryptionCredentials = [ "secret-lab/secure" ];
    passwordTimeout = 0;
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/SECRETEFI";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
    "/" = {
      device = "secret-lab/secure/nixos";
      fsType = "zfs";
    };
    "/nix" = {
      device = "secret-lab/secure/nix";
      fsType = "zfs";
    };
    "/home" = {
      device = "secret-lab/secure/home";
      fsType = "zfs";
    };
  };
  # No unencrypted swap/hibernation image. ZFS root disables unsafe hibernation.
  swapDevices = [ ];
  networking.firewall.enable = true;
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

  # Reuse shared streaming integration, without host LAN aliases, port forwards,
  # credentials or copied pairing state. This test is viewed on Deck's display.
  my.sunshine = {
    enable = true;
    settings = {
      sunshine_name = "secret-lab";
      capture = "kms";
    };
  };
}
