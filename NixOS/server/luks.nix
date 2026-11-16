{ config, lib, ... }:
let
  cfg = config.my.luks;
in
{
  options.my.luks = {
    enable = lib.mkEnableOption "boot unlocking for an explicitly provisioned LUKS root disk";
    device = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/dev/disk/by-partlabel/cryptroot";
      description = "Locked block device. The passphrase is entered at boot and is not stored.";
    };
    fido2 = {
      enable = lib.mkEnableOption "touch-only FIDO2 unlocking of privately enrolled LUKS2 slots";
      deviceTimeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Wait for an absent token before falling back to the recovery password. Not a touch timeout.";
      };
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Mapper name. Mount the unlocked device at /dev/mapper/<name>.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.device != "";
        message = "my.luks.device is required when disk encryption is enabled.";
      }
    ];
    boot.initrd.luks.devices.${cfg.name} = {
      device = cfg.device;
      crypttabExtraOpts = lib.optionals cfg.fido2.enable [
        "fido2-device=auto"
        "fido2-pin=no"
        "fido2-up=yes"
        "fido2-uv=no"
        "token-timeout=${toString cfg.fido2.deviceTimeoutSeconds}s"
      ];
    };
    # Enrollment is private and per-volume. No key, PIN, header or PAM handle
    # enters the initrd; the LUKS header carries systemd-cryptenroll metadata.
    boot.initrd.systemd.fido2.enable = lib.mkIf cfg.fido2.enable true;
    boot.initrd.availableKernelModules = lib.optionals cfg.fido2.enable [
      "usbhid"
      "hid_generic"
      "xhci_pci"
    ];
  };
}
