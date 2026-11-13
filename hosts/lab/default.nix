{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = "lab";
  networking.hostId = "1ab04e01";
  system.stateVersion = "24.11";

  # Install-time disk only. Rebuild does not create or format it.
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  my.desktop.enable = true;

  # virtio-gpu exposes one "Virtual-1" output. Pin it to landscape so the
  # stream is 16:9 instead of the guest's default portrait mode.
  my.desktop.niri.outputs = ''
    output "Virtual-1" {
        mode "1920x1080@60.000"
        scale 1
        transform "normal"
        position x=0 y=0
    }
  '';

  # virtio-gpu has one output. Leave its name unset and let Sunshine select it.
  # The first visit to the forwarded web UI creates the account.
  my.sunshine = {
    enable = true;
    settings = {
      sunshine_name = "lab";
      capture = "kms";
      # The guest is reached through Deck's second LAN address, not localhost.
      # Sunshine's CSRF check rejects any other origin, which also breaks the
      # first account creation and later PIN entry.
      csrf_allowed_origins = "https://192.168.2.131:47990";
    };
  };
}
