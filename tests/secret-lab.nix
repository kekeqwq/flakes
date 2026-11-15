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
assert c.fileSystems."/".device == "secret-lab/secure/nixos";
assert c.fileSystems."/nix".device == "secret-lab/secure/nix";
assert c.fileSystems."/home".device == "secret-lab/secure/home";
assert lib.all (p: c.fileSystems.${p}.fsType == "zfs") [
  "/"
  "/nix"
  "/home"
];
assert c.boot.zfs.requestEncryptionCredentials == [ "secret-lab/secure" ];
assert !c.boot.zfs.forceImportRoot && !c.boot.zfs.unsafeAllowHibernation;
assert c.swapDevices == [ ];
assert c.networking.firewall.enable;
assert !c.services.openssh.settings.PasswordAuthentication;
assert c.services.openssh.settings.PermitRootLogin == "no";
assert c.users.mutableUsers;
assert c.users.users.keke.hashedPassword == null;
assert c.users.users.keke.initialPassword == null;
assert c.services.greetd.settings.initial_session.user == "keke";
assert (builtins.head c.home-manager.users.keke.services.swayidle.timeouts).timeout == 300;
assert c.my.sunshine.enable;
assert !(secretLab.options ? jovian);
assert lab.config.fileSystems."/".fsType == "ext4";
pkgs.runCommand "secret-lab-boundaries"
  {
    # Force full evaluation while leaving installation and all key material private.
    fullSystem = builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath;
    theme = builtins.head c.boot.plymouth.themePackages;
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
  }
  ''
    test -n "$fullSystem"
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
