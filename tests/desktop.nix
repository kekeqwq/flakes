{
  inputs,
  baseModule,
  deck,
  pkgs,
}:
let
  lib = inputs.nixpkgs.lib;
  # Evaluation fixtures only: neither is a flake host or a VM.
  fixture =
    enable:
    lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        baseModule
        {
          my.desktop.enable = enable;
          networking.hostName = "desktop-module-check";
          system.stateVersion = "24.11";
          fileSystems."/" = {
            device = "/dev/disk/by-label/root";
            fsType = "ext4";
          };
          fileSystems."/boot" = {
            device = "/dev/disk/by-label/boot";
            fsType = "vfat";
          };
        }
      ];
    };
  enabled = fixture true;
  disabled = fixture false;
  c = enabled.config;
  off = disabled.config;
  homePackages = system: map toString system.config.home-manager.users.keke.home.packages;
  genericPackages = homePackages enabled;
in
assert !(enabled.options ? jovian);
assert !(disabled.options ? jovian);
assert c.myuser.name == "keke";
assert c.networking.hostName == "desktop-module-check";
assert c.programs.niri.enable && c.services.greetd.enable;
assert c.programs.steam.enable && c.services.sunshine.enable;
assert c.networking.networkmanager.enable && c.hardware.bluetooth.enable;
assert c.services.udisks2.enable && c.services.fwupd.enable;
assert !off.programs.niri.enable && !off.services.greetd.enable && !off.services.sunshine.enable;
assert off.myuser.name == "keke";
assert off.home-manager.users.keke.programs.fish.enable;
assert off.home-manager.users.keke.programs.git.enable;
assert off.home-manager.users.keke.programs.tmux.enable;
assert off.home-manager.users.keke.programs.yazi.enable;
assert off.home-manager.users.keke.programs.pi.coding-agent.enable;
assert off.home-manager.users.keke.programs.emacs.enable;
assert
  toString off.home-manager.users.keke.programs.emacs.package == toString disabled.pkgs.emacs-nox;
assert !off.home-manager.users.keke.programs.wezterm.enable;
assert !off.home-manager.users.keke.programs.obsidian.enable;
assert !(off.home-manager.users.keke.home.file ? ".local/share/emacs-rime-native");
assert c.my.desktop.niri.extraConfig == "";
assert lib.all (font: builtins.elem (toString font) (map toString c.fonts.packages)) [
  enabled.pkgs.dejavu_fonts
  enabled.pkgs.lxgw-wenkai
  enabled.pkgs.nerd-fonts.symbols-only
];
assert !(builtins.elem (toString disabled.pkgs.lxgw-wenkai) (map toString off.fonts.packages));
assert lib.any (font: (font.pname or "") == "monolisa-nasy") c.fonts.packages;
assert !lib.any (font: (font.pname or "") == "monolisa-nasy") off.fonts.packages;
assert
  c.fonts.fontconfig.defaultFonts.sansSerif == [
    "MonoLisa Nasy"
    "LXGW WenKai"
  ];
assert
  c.fonts.fontconfig.defaultFonts.monospace == [
    "MonoLisa Nasy"
    "LXGW WenKai Mono"
  ];
assert lib.all (package: builtins.elem package genericPackages) (homePackages deck);
pkgs.runCommand "desktop-module-boundaries"
  {
    # Force evaluation of the complete ordinary desktop, not only a few options.
    genericSystem = builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath;
    headlessSystem = builtins.unsafeDiscardStringContext off.system.build.toplevel.drvPath;
    niriConfig = c.home-manager.users.keke.xdg.configFile."niri/config.kdl".source;
  }
  ''
    test -n "$genericSystem"
    test -n "$headlessSystem"
    test -s "$niriConfig"
    touch "$out"
  ''
