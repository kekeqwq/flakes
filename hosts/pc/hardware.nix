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
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "amdgpu"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # For Wayland
  # hardware.opengl = {
  #   enable = true;
  #   driSupport = true;
  # };

  # ZFS
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=2G"
      "mode=755"
    ];
  };

  fileSystems."/nix" = {
    device = "tank/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "tank/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "vfat";
  };

  fileSystems."/var/log" = {
    device = "/nix/persist/var/log";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/libvirt" = {
    device = "/nix/persist/var/lib/libvirt";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/postgresql" = {
    device = "/nix/persist/var/lib/postgresql";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/tailscale" = {
    device = "/nix/persist/var/lib/tailscale";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/etc/v2raya" = {
    device = "/nix/persist/v2raya";
    fsType = "none";
    options = [ "bind" ];
  };
  fileSystems."/root/.local/share/v2ray" = {
    device = "/nix/persist/v2ray";
    fsType = "none";
    options = [ "bind" ];
  };

  # swapDevices = [{ device = "/dev/zvol/tank/swap"; }];

  # Btrfs
  # fileSystems."/" = {
  #   device = "none";
  #   fsType = "tmpfs";
  #   options = [ "defaults" "size=2G" "mode=755" ];
  # };

  # fileSystems."/boot" = {
  #   device = "/dev/sda1";
  #   fsType = "vfat";
  # };

  # fileSystems."/nix" = {
  #   device = "/dev/mapper/nix";
  #   fsType = "btrfs";
  #   options = [ "subvol=nix" "noatime" "compress-force=zstd" ];
  # };

  # boot.initrd.luks.devices."nix".device = "/dev/sda2";

  # fileSystems."/home" = {
  #   device = "/dev/mapper/nix";
  #   fsType = "btrfs";
  #   options = [ "subvol=home" "noatime" "compress-force=zstd" ];
  # };

  # fileSystems."/var/log" = {
  #   device = "/nix/persist/var/log";
  #   fsType = "none";
  #   options = [ "bind" ];
  # };

  # fileSystems."/var/lib/libvirt" = {
  #   device = "/nix/persist/var/lib/libvirt";
  #   fsType = "none";
  #   options = [ "bind" ];
  # };
}
