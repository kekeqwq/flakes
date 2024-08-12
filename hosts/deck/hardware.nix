{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usbhid"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/boot" = {
    device = "/dev/nvme0n1p1";
    fsType = "vfat";
    # TODO:
    # FIx:
    # ⚠️ Mount point '/boot' which backs the random seed file is world accessible, which is a security hole! ⚠️
    # ⚠️ Random seed file '/boot/loader/.#bootctlrandom-seed27820771c01feea9' is world accessible, which is a security hole! ⚠
    options = [ "umask=0077" "defaults" ];

  };

  fileSystems."/" = {
    device = "deck/nixos";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "deck/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "deck/home";
    fsType = "zfs";
  };

  swapDevices = [ ];
}
