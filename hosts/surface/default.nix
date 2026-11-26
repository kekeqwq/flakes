{
  config,
  lib,
  pkgs,
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
  # Keep the LUKS prompt and early display diagnostics on the built-in console.
  boot.plymouth.enable = lib.mkForce false;
  boot.consoleLogLevel = 7;
  boot.kernelParams = [
    "nohibernate"
    "console=tty0"
    "fbcon=font:TER16x32,nodefer"
    "rd.systemd.show_status=yes"
    "systemd.show_status=yes"
  ];
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
  # Boot A/B: reuse the hardware-tested Live kernel and DTB with this host's
  # installed userspace and encrypted root, not the Live login policy.
  specialisation.live-kernel.configuration =
    let
      live = inputs.surface-live-baseline.nixosConfigurations.surface-live.config;
    in {
      system.nixos.tags = [ "live-kernel-ab" ];
      surface.fullio.referenceRender.enable = false;
      surface.fullio.checkedCapture = lib.mkForce false;
      surface.fullio.swrResumeAudit = lib.mkForce false;
      surface.fullio.feedbackParityRender = lib.mkForce false;
      boot.kernelPackages = lib.mkForce live.boot.kernelPackages;
      hardware.deviceTree.package = lib.mkForce live.hardware.deviceTree.package;
      boot.initrd.systemd.storePaths = [ "${pkgs.coreutils}/bin/printf" "${pkgs.coreutils}/bin/sleep" ];
      boot.initrd.systemd.services.denali-console-proof = {
        description = "Show the Denali console checkpoint before LUKS";
        wantedBy = [ "systemd-cryptsetup@cryptroot.service" ];
        before = [ "systemd-cryptsetup@cryptroot.service" ];
        after = [ "systemd-modules-load.service" "systemd-udev-trigger.service" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          StandardOutput = "tty";
          TTYPath = "/dev/tty0";
          ExecStart = ''${pkgs.coreutils}/bin/printf "\\nSURFACE: early console visible (before LUKS)\\n\\n"'';
          ExecStartPost = "${pkgs.coreutils}/bin/sleep 3";
          TimeoutStartSec = "8s";
        };
      };
    };
  # A Btrfs swapfile can be added inside cryptroot later without repartitioning.
  swapDevices = [ ];
}
