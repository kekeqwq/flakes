{
  config,
  lib,
  inputs,
  ...
}:
let
  dailyBoot = inputs.surface.denaliDailyBoot;
  btrfsSubvolume = name: {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvol=${name}"
      "compress=zstd:5"
      "noatime"
    ];
  };
in
{
  imports = [
    ../../NixOS/desktop/baseline.nix
    ./sunshine-output.nix
    inputs.surface.nixosModules.default
    inputs.surface.nixosModules.denali-qce-experiment
    inputs.surface.nixosModules.fullio-reference-render
    inputs.surface.nixosModules.fullio-reference-clock-audit
  ];

  networking.hostName = "surface";
  networking.networkmanager.enable = true;
  # First installation on NixOS 27.05; never bump on rebuild.
  system.stateVersion = "27.05";

  security.rtkit.enable = true;
  surface.devices.denali = {
    enable = true;
    boot = {
      earlyDisplay = true;
      earlyBrightnessPercent = 100;
    };
    keyboard.hhkb.enable = true;
    # Native finger touch, accepted on the Next24 transport and response timing.
    touchscreen.native.enable = true;
    # Isolated ICC sync_state trial; do not change touch or lid behavior.
    power.disableUnusedQce = true;
    privateFirmwareDirectory = "/var/lib/surface-firmware";
    # This device lacks an accessible factory Bluetooth address.
    bluetoothAddress = "02:11:5A:AD:00:01";
  };
  # SAM and Qualcomm report the same physical pack. Display the SAM gauge.
  my.desktop.battery.device = "BAT1";
  my.desktop.niri.outputs = config.surface.devices.denali.niriOutputs;
  # Stream the physical external display without creating a virtual output.
  my.sunshine = {
    enable = true;
    proxy = false;
    settings.sunshine_name = "surface";
  };

  my.luks = {
    enable = true;
    name = "cryptroot";
    device = "/dev/disk/by-partlabel/surface-cryptroot";
    fido2.enable = true;
  };
  # The Type-C host controller is built in, but its board PHY suppliers
  # are modular. Load them before the initrd attempts FIDO2 discovery.
  boot.initrd.kernelModules = [
    "phy-qcom-eusb2-repeater"
    "phy-qcom-qmp-combo"
    "phy-snps-eusb2"
  ];
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "vfat"
  ];
  # This volume uses LUKS2 AES-XTS; cryptsetup handles key derivation
  # through OpenSSL/libargon2, not the optional kernel AF_ALG interface.
  # Do not request the generic initrd list's unbuilt legacy ciphers.
  boot.initrd.luks.cryptoModules = [
    "aes"
    "xts"
    "sha256"
    "sha512"
    "input_leds"
  ];
  # Keep the defaults set by luksroot.nix: its lvm2 package supplies the
  # device-mapper udev rules and dmsetup even for LUKS directly over Btrfs.
  # The hardware flake owns the single validated internal-boot payload.
  boot.kernelPackages = lib.mkOverride 30 dailyBoot.kernelPackages;
  # The explicit native-touch module may replace only this DTB, not the kernel.
  hardware.deviceTree.package = lib.mkOverride 60 dailyBoot.dtbs;
  # Use the shared desktop Plymouth/FIDO2 path.
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
    "/nix" = (btrfsSubvolume "@nix") // {
      neededForBoot = true;
    };
    "/home" = btrfsSubvolume "@home";
  };
  # A Btrfs swapfile can be added inside cryptroot later without repartitioning.
  swapDevices = [ ];
}
