{
  pkgs,
  inputs,
  baseModule,
  desktop,
}:
let
  headless = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      baseModule
      {
        networking.hostName = "arm-headless-check";
        system.stateVersion = "24.11";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/disk/by-label/root";
          fsType = "ext4";
        };
      }
    ];
  };
  cfg = desktop.config;
  hm = cfg.home-manager.users.keke;
  packages = map (p: p.pname or (p.name or "")) (cfg.environment.systemPackages ++ hm.home.packages);
  excluded = [
    "spotify"
    "spotify-spotx"
    "discord"
    "snipaste"
    "via"
    "steam"
  ];
in
assert desktop.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
assert cfg.my.desktop.enable && !headless.config.my.desktop.enable;
assert cfg.programs.niri.enable && !cfg.programs.steam.enable;
assert !(hm.systemd.user.services ? snipaste);
assert builtins.elem "eca" packages;
assert builtins.all (name: !(builtins.elem name packages)) excluded;
assert builtins.isString desktop.config.system.build.toplevel.drvPath;
assert builtins.isString headless.config.system.build.toplevel.drvPath;
pkgs.runCommand "aarch64-linux-package-boundaries" { } ''
  ${desktop.pkgs.eca}/bin/eca --version | grep -F '${desktop.pkgs.eca.version}'
  touch "$out"
''
