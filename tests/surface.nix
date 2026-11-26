{ pkgs, surface }:
let
  cfg = surface.config;
  lib = pkgs.lib;
  unity = cfg.surface.fullio.feedbackParityRender or false;
  keeper = cfg.systemd.user.services.fullio-endpoint-keeper;
  holder = cfg.systemd.user.services.fullio-graph-holder;
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
assert lib.hasSuffix (
  if unity then "-surface-fullio-checked-capture" else "-surface-fullio"
) cfg.boot.kernelPackages.kernel.modDirVersion;
assert builtins.elem "default.target" holder.wantedBy;
assert builtins.elem "default.target" keeper.wantedBy;
assert lib.hasSuffix " 0" keeper.serviceConfig.ExecStart == unity;
assert !unity || (
  keeper.serviceConfig.Restart == "no"
  && cfg.surface.fullio.checkedCapture
  && cfg.surface.fullio.swrResumeAudit
  && !cfg.surface.fullio.feedbackParityAudit
  && !cfg.surface.fullio.preSpLoggerAudit
  && cfg.security.rtkit.enable
);
assert !(cfg.systemd.user.services ? fullio-audio-monitor);
assert builtins.all (
  name: !(lib.hasPrefix "sp11-fullio-" name || lib.hasPrefix "fullio-audio-" name)
) names;
assert cfg.hardware.deviceTree.name == "qcom/x1e80100-microsoft-denali-oled.dtb";
assert cfg.my.desktop.niri.outputs == cfg.surface.devices.denali.niriOutputs;
assert cfg.my.desktop.niri.extraConfig == "";
assert !(cfg.environment.sessionVariables ? FD_MESA_DEBUG);
assert cfg.home-manager.users.keke.programs.ghostty.settings.background-opacity == [ 0.70 ];
assert cfg.networking.hostName == "surface" && cfg.networking.networkmanager.enable;
assert cfg.system.stateVersion == "27.05";
assert cfg.surface.devices.denali.keyboard.hhkb.enable;
assert cfg.fileSystems."/boot".device == "/dev/disk/by-partlabel/surface-efi";
assert cfg.fileSystems."/boot".fsType == "vfat";
assert lib.all (path: let fs = cfg.fileSystems.${path}; in
  fs.fsType == "btrfs" && fs.device == "/dev/mapper/cryptroot"
  && builtins.elem "compress=zstd:3" fs.options
) [ "/" "/nix" "/home" ];
assert cfg.fileSystems."/nix".neededForBoot;
assert cfg.swapDevices == [ ];
assert builtins.elem "nohibernate" cfg.boot.kernelParams;
assert cfg.my.luks.enable && cfg.boot.initrd.systemd.fido2.enable;
assert cfg.boot.initrd.luks.devices.cryptroot.device == "/dev/disk/by-partlabel/surface-cryptroot";
assert lib.all (opt: builtins.elem opt cfg.boot.initrd.luks.devices.cryptroot.crypttabExtraOpts)
  [ "fido2-device=auto" "fido2-pin=no" "fido2-up=yes" "tries=0" ];
assert cfg.services.sunshine.enable && !cfg.my.sunshine.proxy;
assert cfg.services.sunshine.settings.output_name == "eDP-1";
assert cfg.services.sunshine.settings.upnp == "disabled";
assert !(cfg.services.nginx.virtualHosts ? sunshine-proxy);
assert !cfg.services.qemuGuest.enable;
assert !cfg.boot.loader.grub.enable && cfg.boot.loader.systemd-boot.enable;
assert cfg.boot.loader.systemd-boot.consoleMode == "auto";
assert !lib.any (lib.hasPrefix "plymouth.use-simpledrm") cfg.boot.kernelParams;
assert cfg.system.activationScripts.surfacePrivateFirmware.deps == [ "udevd" ];
assert !(lib.any (rule: builtins.elem "keke" rule.users) cfg.security.sudo.extraRules);
assert cfg.security.sudo.wheelNeedsPassword;
assert cfg.services.openssh.enable && !(cfg.services.openssh.settings.PermitEmptyPasswords or false);
assert !(lib.hasInfix "Match User keke" cfg.services.openssh.extraConfig);
assert !(cfg.security.pam.services.sshd.rules.auth ? surface-test-keke);
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
