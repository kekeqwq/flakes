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
assert c.programs.niri.enable && c.services.greetd.enable && !c.services.greetd.restart;
assert c.services.greetd.settings.initial_session.user == "keke";
assert lib.hasInfix "niri-session" c.services.greetd.settings.initial_session.command;
assert !c.my.luks.enable && !off.my.luks.enable;
assert !deck.config.services.greetd.enable;
assert c.programs.steam.enable && !c.services.sunshine.enable;
assert !c.my.sunshine.enable && !off.my.sunshine.enable;
assert !off.services.sunshine.enable;
assert deck.config.my.sunshine.enable && deck.config.my.sunshine.proxy;
assert deck.config.my.sunshine.capture == "DP-1";
assert deck.config.services.sunshine.settings.output_name == "DP-1";
assert deck.config.services.sunshine.settings.capture == "kms";
assert !(c.services.nginx.virtualHosts ? sunshine-proxy);
assert
  deck.config.services.nginx.virtualHosts.sunshine-proxy.locations."/".proxyPass
  == "https://127.0.0.1:47990";
assert !c.services.qbittorrent.enable && !off.services.qbittorrent.enable;
assert deck.config.services.qbittorrent.enable;
assert deck.config.services.qbittorrent.package.pname == "qbittorrent-enhanced-nox";
assert deck.config.services.qbittorrent.package.version == "5.2.4.10";
assert
  deck.config.systemd.tmpfiles.settings.qbittorrent-downloads."/var/lib/qBittorrent/downloads".d.user
  == deck.config.services.qbittorrent.user;
assert !(deck.config.systemd.services ? sing-box);
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
assert c.my.desktop.niri.extraConfig == "" && c.my.desktop.niri.outputs == "";
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
assert !(c.systemd.services ? openlist) && !(off.systemd.services ? openlist);
assert deck.config.systemd.services.openlist.enable;
assert deck.config.systemd.services.openlist.serviceConfig.WorkingDirectory == "/home/keke";
assert c.i18n.inputMethod.enable && c.i18n.inputMethod.type == "fcitx5";
assert !c.i18n.inputMethod.fcitx5.ignoreUserConfig;
# Bare fcitx5 shadows the wrapped binary and XDG autostart entry.
assert !(builtins.elem (toString enabled.pkgs.fcitx5) (map toString c.environment.systemPackages));
assert lib.hasInfix "DefaultIM=rime" c.home-manager.users.keke.xdg.configFile."fcitx5/profile".text;
assert lib.hasInfix "double_pinyin_flypy"
  c.home-manager.users.keke.xdg.dataFile."fcitx5/rime/default.custom.yaml".text;
assert !(off.home-manager.users.keke.xdg.dataFile ? "fcitx5/rime/default.custom.yaml");
assert
  c.home-manager.users.keke.xdg.mimeApps.defaultApplications."text/html"
  == [ "google-chrome.desktop" ];
assert
  c.home-manager.users.keke.dconf.settings."org/gnome/desktop/interface".cursor-theme
  == "Bibata-Modern-Ice";
assert lib.all (
  rule: rule ? mime && lib.hasPrefix "vfs/" rule.mime || builtins.elem "send" rule.use
) c.home-manager.users.keke.programs.yazi.settings.open.rules;
assert lib.all (package: builtins.elem package genericPackages) (homePackages deck);
pkgs.runCommand "desktop-module-boundaries"
  {
    # Force evaluation of the complete ordinary desktop, not only a few options.
    genericSystem = builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath;
    headlessSystem = builtins.unsafeDiscardStringContext off.system.build.toplevel.drvPath;
    niriConfig = c.home-manager.users.keke.xdg.configFile."niri/config.kdl".source;
    nativeBuildInputs = [ pkgs.librime ];
    rimeData = builtins.head (
      builtins.filter (p: (p.pname or "") == "fcitx5-rime") c.i18n.inputMethod.fcitx5.addons
    );
    rimeCustom =
      pkgs.writeText "rime-default.custom.yaml"
        c.home-manager.users.keke.xdg.dataFile."fcitx5/rime/default.custom.yaml".text;
  }
  ''
    test -n "$genericSystem"
    test -n "$headlessSystem"
    test -s "$niriConfig"
    # Prove a new instance can build the selected schema without copying any
    # existing user's training database or generated Rime caches.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" user/build
    cp "$rimeCustom" user/default.custom.yaml
    rime_deployer --build "$PWD/user" "$rimeData/share/rime-data" "$PWD/user/build"
    test -s user/build/double_pinyin_flypy.schema.yaml
    test -s user/build/double_pinyin_flypy.prism.bin
    touch "$out"
  ''
