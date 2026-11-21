{ pkgs, surface }:
let
  cfg = surface.config;
  lib = pkgs.lib;
  packages = cfg.environment.systemPackages ++ cfg.home-manager.users.keke.home.packages;
  names = map (p: p.pname or (p.name or "")) packages;
  excluded = [
    "spotify"
    "spotify-spotx"
    "discord"
    "snipaste"
    "via"
    "steam"
  ];
in
assert surface.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
assert cfg.my.desktop.enable && cfg.programs.niri.enable;
assert cfg.services.iptsd.enable;
assert cfg.surface.devices.denali.enable;
assert cfg.boot.kernelPackages.kernel == surface.pkgs.surfacePackages.surfaceNext;
assert cfg.hardware.deviceTree.name == "qcom/x1e80100-microsoft-denali-oled.dtb";
assert cfg.my.desktop.niri.outputs == cfg.surface.devices.denali.niriOutputs;
assert cfg.my.desktop.niri.extraConfig == "";
assert !(cfg.environment.sessionVariables ? FD_MESA_DEBUG);
assert cfg.home-manager.users.keke.programs.ghostty.settings.background-opacity == 0.70;
assert cfg.fileSystems."/".fsType == "ext4";
assert cfg.fileSystems."/".device == "/dev/disk/by-label/NIXOS_ROOT";
assert !cfg.my.luks.enable && cfg.boot.initrd.luks.devices == { };
assert !cfg.services.qemuGuest.enable;
assert !cfg.boot.loader.grub.enable && cfg.boot.loader.systemd-boot.enable;
assert cfg.system.activationScripts.surfacePrivateFirmware.deps == [ "udevd" ];
assert cfg.security.pam.services.sudo.u2f.enable;
assert cfg.security.pam.services.sudo-i.u2f.enable;
assert cfg.environment.etc."security/flakes-u2f-keys".enable;
assert lib.hasInfix "pam_u2f.so" cfg.security.pam.services.swaylock-key.text;
assert !cfg.programs.steam.enable;
assert builtins.all (name: !(builtins.elem name names)) excluded;
assert builtins.all (p: lib.meta.availableOn surface.pkgs.stdenv.hostPlatform p) packages;
assert builtins.isString cfg.system.build.toplevel.drvPath;
assert builtins.isString cfg.system.build.uki.drvPath;
pkgs.runCommand "surface-formal-desktop-boundaries" { } ''
  touch "$out"
''
