{
  config,
  lib,
  inputs,
  ...
}:
let
  btrfsSubvolume = name: {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvol=${name}"
      "compress=zstd:3"
      "noatime"
    ];
  };
in
{
  imports = [
    ../../NixOS/desktop/baseline.nix
    inputs.surface.nixosModules.default
    inputs.surface.nixosModules.fullio-reference-render
    inputs.surface.nixosModules.fullio-reference-clock-audit
  ];

  networking.hostName = "surface";
  networking.networkmanager.enable = true;
  # First installation on NixOS 27.05; never bump on rebuild.
  system.stateVersion = "27.05";

  security.rtkit.enable = true;
  surface.fullio = {
    checkedCapture = true;
    swrResumeAudit = true;
    feedbackParityRender = true;
  };
  surface.devices.denali = {
    enable = true;
    keyboard.hhkb.enable = true;
    privateFirmwareDirectory = "/var/lib/surface-firmware";
    # This device lacks an accessible factory Bluetooth address.
    bluetoothAddress = "02:11:5A:AD:00:01";
  };
  # Stream the built-in OLED as-is. No separate output or virtual monitor.
  my.desktop.niri.outputs = config.surface.devices.denali.niriOutputs;
  my.sunshine = {
    enable = true;
    capture = "eDP-1";
    proxy = false;
    settings.sunshine_name = "surface";
  };

  my.luks = {
    enable = true;
    name = "cryptroot";
    device = "/dev/disk/by-partlabel/surface-cryptroot";
    fido2.enable = true;
  };
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "vfat"
  ];
  # This volume uses LUKS2 AES-XTS; cryptsetup handles key derivation
  # through OpenSSL/libargon2, not the optional kernel AF_ALG interface.
  # Do not request the generic initrd list's unbuilt legacy ciphers.
  boot.initrd.luks.cryptoModules = [ "aes" "xts" "sha256" "sha512" "input_leds" ];
  # LUKS maps a raw partition directly to Btrfs, with no LVM layer.
  boot.initrd.services.lvm.enable = lib.mkForce false;
  boot.kernelParams = [ "nohibernate" ];
  boot.loader.timeout = 5;
  boot.loader.systemd-boot.configurationLimit = 8;
  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-partlabel/surface-efi";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
    "/" = btrfsSubvolume "@root";
    "/nix" = (btrfsSubvolume "@nix") // { neededForBoot = true; };
    "/home" = btrfsSubvolume "@home";
  };
  # A Btrfs swapfile can be added inside cryptroot later without repartitioning.
  swapDevices = [ ];
}
