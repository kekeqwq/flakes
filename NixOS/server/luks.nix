{ config, lib, ... }:
let
  cfg = config.my.luks;
in
{
  options.my.luks = {
    enable = lib.mkEnableOption "a boot passphrase prompt for the root disk";
    device = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/dev/disk/by-partlabel/cryptroot";
      description = "Locked block device. The passphrase is entered at boot and is not stored.";
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
    boot.initrd.luks.devices.${cfg.name}.device = cfg.device;
  };
}
