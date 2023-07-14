{ config, pkgs, lib, ... }: {
  # Local Firesystem(ZFS)
  boot.zfs.requestEncryptionCredentials = [ "tank" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  ## ZFS
  boot.kernelPackages =
    lib.mkForce config.boot.zfs.package.latestCompatibleLinuxPackages;
  # Power Management
  #services.logind.extraConfig = ''
  #  IdleAction=hybrid-sleep
  #  IdleActionSec=1min
  #'';
  boot.zfs.devNodes =
    "/dev/disk/by-id/ata-PLEXTOR_PX-512M8VC_P02011403287-part2";

  # root on tmpfs
  users.mutableUsers = false;
  myuser.users.initialHashedPassword =
    "$6$01tf1dfctTu10Yj0$/3wpVVRxR.5QQs8Dww2LMY4sFRks35IG/miXcpwUjkhWD2M/olSCV05RATV5itbAXOE3oI4CKsD4UnkZOjzZ1.";
  environment.etc."machine-id".source = "/nix/persist/etc/machine-id";
  environment.etc."ssh/ssh_host_rsa_key".source =
    "/nix/persist/etc/ssh/ssh_host_rsa_key";
  environment.etc."ssh/ssh_host_rsa_key.pub".source =
    "/nix/persist/etc/ssh/ssh_host_rsa_key.pub";
  environment.etc."ssh/ssh_host_ed25519_key".source =
    "/nix/persist/etc/ssh/ssh_host_ed25519_key";
  environment.etc."ssh/ssh_host_ed25519_key.pub".source =
    "/nix/persist/etc/ssh/ssh_host_ed25519_key.pub";

  # Networking
  networking.hostId = "00bab10c";
  networking.useDHCP = false;
  networking.interfaces.enp34s0.useDHCP = true;
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = { "br0" = { interfaces = [ "enp34s0" ]; }; };
  networking.firewall.enable = false;
  networking.extraHosts = ''
    140.82.113.3 gist.github.com
    185.199.108.133 raw.githubusercontent.com
  '';
  # networking.proxy.default = "http://127.0.0.1:7890";

  # File Shareing
  # programs.mosh.enable = true;
  # services.zerotierone.enable = true;
  # services.zerotierone.joinNetworks = [ "b15644912e5357b7" ];
  services.tailscale.enable = true;

  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = pc
      netbios name = pc
      security = user 
      #use sendfile = yes
      #max protocol = smb2
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      # Poorpool = {
      #   path = "/mnt";
      #   browseable = "yes";
      #   "read only" = "no";
      #   "guest ok" = "no";
      #   "create mask" = "0644";
      #   "directory mask" = "0755";
      # };
      Home = {
        path = "/home/me/Downloads";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };


  # Users
  myuser.name = "me";
  # users.groups.uinput = { };
  myuser.users = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAojYQZoakphJU+/HM3dWETjND4+duXFi2CFHKELPXv0 me"
    # ];
  };


  # myuser.hm.programs.ssh = {
  #   enable = true;
  #   matchBlocks = {
  #     "192.168.2.2".user = "gitolite";
  #     "192.168.2.2".identityFile = "~/.ssh/nas";
  #   };
  # };

  # Udev For Xkeysnail
  # services.udev.extraRules = ''
  #   KERNEL=="uinput", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
  #   KERNEL=="event[0-9]*", GROUP="uinput", MODE="0660"
  #   ACTION=="add|change", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  # '';

  # Podman
  # virtualisation = {
  #   podman = {
  #     enable = true;
  #     # Create a `docker` alias for podman, to use it as a drop-in replacement
  #     dockerCompat = true;
  #   };
  # };

  # System
  system.stateVersion = "22.05";
  myuser.hm.home.stateVersion = "22.05";
}
