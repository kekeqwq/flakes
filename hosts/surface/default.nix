{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
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
    # This test device lacks an accessible factory Bluetooth address.
    bluetoothAddress = "02:11:5A:AD:00:01";
  };
  my.desktop.niri.outputs = config.surface.devices.denali.niriOutputs;

  # Test system: ext4 root + vfat ESP only. The formal install will add
  # LUKS2/Btrfs later; keeping NTFS/LVM out lets the kernel stay minimal.
  boot.supportedFilesystems = lib.mkForce [
    "ext4"
    "vfat"
  ];
  boot.initrd.services.lvm.enable = false;

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

  # Dedicated test machine only. Remove before formal deployment.
  security.sudo.extraRules = [
    {
      users = [ "keke" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users.mutableUsers = true;
  services.openssh.authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
    PermitEmptyPasswords = false;
  };
  # Dedicated test host only. OpenSSH's `none` request checks the empty
  # password via PAM; substitute a host-local exception for keke, without
  # touching the shadow password, local login PAM, or other SSH accounts.
  services.openssh.extraConfig = ''
    Match User keke
      PasswordAuthentication yes
      PermitEmptyPasswords yes
  '';
  security.pam.services.sshd.rules.auth.surface-test-keke = {
    order = 100;
    control = "sufficient";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
    args = [
      "quiet"
      "user"
      "="
      "keke"
    ];
  };
}
