{
  pkgs,
  secretLab,
  lab,
}:
let
  c = secretLab.config;
  lib = pkgs.lib;
in
assert c.my.desktop.enable && c.boot.plymouth.enable;
assert c.boot.plymouth.theme == "keke";
assert c.networking.hostName == "secret-lab";
assert c.networking.hostId != lab.config.networking.hostId;
assert c.my.luks.enable && c.my.luks.fido2.enable;
assert c.boot.initrd.systemd.fido2.enable;
assert c.my.luks.fido2.deviceTimeoutSeconds == 10;
assert c.boot.initrd.systemd.services.plymouth-fido2-wait.wantedBy == [ "sysinit.target" ];
assert c.boot.initrd.luks.devices.cryptroot.device == "/dev/disk/by-partlabel/secret-lab-cryptroot";
assert c.boot.initrd.luks.devices.cryptroot.keyFile == null;
assert lib.all (opt: builtins.elem opt c.boot.initrd.luks.devices.cryptroot.crypttabExtraOpts) [
  "tries=0"
  "fido2-device=auto"
  "fido2-pin=no"
  "fido2-up=yes"
  "fido2-uv=no"
  "token-timeout=10s"
];
assert lib.all
  (
    p:
    c.fileSystems.${p}.device == "/dev/mapper/cryptroot"
    && c.fileSystems.${p}.fsType == "btrfs"
    && builtins.elem "compress=zstd:3" c.fileSystems.${p}.options
  )
  [
    "/"
    "/nix"
    "/home"
  ];
assert builtins.elem "subvol=@root" c.fileSystems."/".options;
assert builtins.elem "subvol=@nix" c.fileSystems."/nix".options;
assert builtins.elem "subvol=@home" c.fileSystems."/home".options;
assert !(c.boot.supportedFilesystems.zfs or false);
assert builtins.elem "nohibernate" c.boot.kernelParams;
assert c.swapDevices == [ ];
assert c.networking.firewall.enable;
assert !c.services.openssh.settings.PasswordAuthentication;
assert c.services.openssh.settings.PermitRootLogin == "no";
assert c.users.mutableUsers;
assert c.users.users.keke.hashedPassword == null;
assert c.users.users.keke.initialPassword == null;
assert c.services.greetd.settings.initial_session.user == "keke";
assert c.programs.niri.package.explicitSessionEnvironment;
assert
  c.services.greetd.settings.initial_session.command == "${c.programs.niri.package}/bin/niri-session";
assert
  c.services.greetd.settings.default_session.command == "${c.programs.niri.package}/bin/niri-session";
assert (builtins.head c.home-manager.users.keke.services.swayidle.timeouts).timeout == 300;
assert !c.my.sunshine.enable && !c.services.sunshine.enable;
assert c.services.qemuGuest.enable;
assert !(secretLab.options ? jovian);
assert lab.config.fileSystems."/".fsType == "ext4";
pkgs.runCommand "secret-lab-boundaries"
  {
    # Force full evaluation while leaving installation and all key material private.
    fullSystem = builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath;
    theme = builtins.head c.boot.plymouth.themePackages;
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
    safetyTests = ./secret-lab-safety.py;
    sourceTree = ../.;
  }
  ''
    test -n "$fullSystem"
    python3 "$safetyTests" "$sourceTree"
    test -s "$theme/share/plymouth/themes/keke/keke.script"
    python3 - "$theme" <<'PY'
    import sys
    from pathlib import Path
    from PIL import Image
    root = Path(sys.argv[1]) / "share/plymouth/themes/keke"
    for name in ("background", "logo", "entry", "bullet", *(f"spinner-{i}" for i in range(36))):
        with Image.open(root / (name + ".png")) as image:
            image.verify()
    PY
    touch "$out"
  ''
