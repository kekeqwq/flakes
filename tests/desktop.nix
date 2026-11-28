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
  niriConfig = builtins.readFile ../NixOS/desktop/niri/config.kdl;
  lockEvents = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };
in
assert !(enabled.options ? jovian);
assert !(disabled.options ? jovian);
assert c.myuser.name == "keke";
assert c.networking.hostName == "desktop-module-check";
assert c.programs.niri.enable && c.services.greetd.enable && !c.services.greetd.restart;
assert c.boot.plymouth.enable && !off.boot.plymouth.enable;
assert c.boot.plymouth.theme == "keke";
assert c.boot.loader.systemd-boot.consoleMode == "auto";
assert off.boot.loader.systemd-boot.consoleMode == "auto";
assert deck.config.boot.loader.systemd-boot.consoleMode == "auto";
assert
  c.systemd.services.plymouth-quit.serviceConfig.ExecStart == [
    ""
    "-${lib.getExe' c.boot.plymouth.package "plymouth"} quit --retain-splash"
  ];
assert lib.all
  (
    unit:
    let
      service = c.systemd.services.${unit};
    in
    builtins.elem "systemd-logind.service" service.after
    && lib.hasSuffix "/bin/setlogcons --console=/dev/tty63 63" service.serviceConfig.ExecStartPre
    && !(off.systemd.services ? ${unit})
  )
  [
    "plymouth-halt"
    "plymouth-poweroff"
    "plymouth-reboot"
  ];
assert builtins.elem "keke-wallpaper.cpio" c.system.boot.extraInitrd.paths;
assert !(builtins.elem "keke-wallpaper.cpio" off.system.boot.extraInitrd.paths);
assert !(c.home-manager.users.keke.systemd.user.services ? wallpaper-polkit-agent);
assert !(off.home-manager.users.keke.systemd.user.services ? wallpaper-polkit-agent);
assert
  c.system.activationScripts ? seedWallpaper && !(off.system.activationScripts ? seedWallpaper);
assert (
  let
    wallpaper = import ../NixOS/desktop/wallpaper-runtime.nix {
      config = c;
      inherit pkgs;
      inherit (inputs.nixpkgs) lib;
    };
    common = import ../NixOS/desktop/control-center-actions.nix { inherit pkgs wallpaper; };
    wallpapers = builtins.filter (a: lib.hasPrefix "wallpaper-" a.id) common;
    byId = id: lib.findFirst (a: a.id == id) null wallpapers;
    delete = byId "wallpaper-delete";
  in
  lib.all (id: byId id != null) [
    "wallpaper-random"
    "wallpaper-sfw"
    "wallpaper-default"
    "wallpaper-delete"
  ]
  && lib.all (a: a.auth == "sudo" && lib.length a.argv == 2) wallpapers
  && lib.all (a: lib.last a.argv == lib.removePrefix "wallpaper-" a.id) wallpapers
  && delete.requires_nonempty_file == "/var/lib/keke-plymouth/current-source"
  && delete.confirm
  && delete.confirm_message != null
  && (byId "wallpaper-default").confirm == false
);
assert c.my.desktop.controlCenter.extraActions == [ ];
assert !(off.home-manager.users.keke.xdg.configFile ? "keke-waybar-panel/actions.json");
assert map (a: a.id) deck.config.my.desktop.controlCenter.extraActions == [ "steam" ];
assert
  (builtins.head deck.config.my.desktop.controlCenter.extraActions).argv == [
    "${deck.pkgs.jovianPackages.steamos-manager}/bin/steamosctl"
    "switch-to-game-mode"
  ];
assert c.systemd.services.greetd.serviceConfig.StandardOutput == "journal";
assert !c.systemd.services.greetd.serviceConfig.TTYVTDisallocate;
assert c.services.greetd.settings.initial_session.user == "keke";
assert c.programs.niri.package.explicitSessionEnvironment;
assert
  c.services.greetd.settings.initial_session.command == "${c.programs.niri.package}/bin/niri-session";
assert
  c.services.greetd.settings.default_session.command == "${c.programs.niri.package}/bin/niri-session";
assert deck.config.programs.niri.package.explicitSessionEnvironment;
assert !c.my.luks.enable && !off.my.luks.enable;
assert !deck.config.services.greetd.enable;
assert c.programs.steam.enable && !c.services.sunshine.enable;
assert c.services.tailscale.enable && off.services.tailscale.enable;
assert c.home-manager.users.keke.programs.zoxide.enable;
assert c.home-manager.users.keke.programs.zoxide.enableFishIntegration;
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
assert lib.hasInfix "--tty --alternate-editor=false $argv"
  off.home-manager.users.keke.programs.fish.functions.e.body;
assert off.home-manager.users.keke.programs.git.enable;
assert off.home-manager.users.keke.programs.tmux.enable;
assert off.home-manager.users.keke.programs.yazi.enable;
assert off.home-manager.users.keke.programs.pi.coding-agent.enable;
assert off.home-manager.users.keke.programs.emacs.enable;
assert c.home-manager.users.keke.services.emacs.enable;
assert off.home-manager.users.keke.services.emacs.enable;
assert c.users.users.keke.linger && off.users.users.keke.linger;
assert c.home-manager.users.keke.services.emacs.startWithUserSession == true;
assert off.home-manager.users.keke.services.emacs.startWithUserSession == true;
assert c.home-manager.users.keke.services.emacs.client.enable;
assert !off.home-manager.users.keke.services.emacs.client.enable;
assert c.home-manager.users.keke.systemd.user.services.emacs.Service.Type == "notify";
assert lib.hasInfix "--fg-daemon" (
  lib.concatStringsSep " " (
    lib.toList c.home-manager.users.keke.systemd.user.services.emacs.Service.ExecStart
  )
);
assert lib.hasInfix "emacsclient --create-frame --no-wait --alternate-editor=false"
  c.home-manager.users.keke.xdg.desktopEntries.emacs.exec;
assert !(off.home-manager.users.keke.xdg.desktopEntries ? emacs);
assert
  toString off.home-manager.users.keke.programs.emacs.package
  == toString disabled.pkgs.emacs-head-nox;
assert !off.home-manager.users.keke.programs.swaylock.enable;
assert !off.home-manager.users.keke.services.swayidle.enable;
assert !(off.home-manager.users.keke.systemd.user.services ? snipaste);
assert c.home-manager.users.keke.services.swayidle.enable;
assert
  c.home-manager.users.keke.systemd.user.services.swayidle.Unit.ConditionEnvironment == [
    "WAYLAND_DISPLAY"
    "XDG_CURRENT_DESKTOP=niri"
  ];
assert lib.hasInfix "Super+L" niriConfig;
assert lib.hasInfix "disable-power-key-handling" niriConfig;
assert lib.hasInfix ''
  XF86PowerOff repeat=false allow-inhibiting=false hotkey-overlay-title="Lock screen" {
          spawn "screen-lock"'' niriConfig;
assert lib.all (
  key:
  c.services.logind.settings.Login.${key} == lockEvents.${key}
  && deck.config.services.logind.settings.Login.${key} == lockEvents.${key}
  && !(off.services.logind.settings.Login ? ${key})
) (builtins.attrNames lockEvents);
assert lib.hasSuffix "/bin/screen-lock" c.home-manager.users.keke.services.swayidle.events.lock;
assert (builtins.head c.home-manager.users.keke.services.swayidle.timeouts).timeout == 300;
assert c.home-manager.users.keke.programs.swaylock.package == enabled.pkgs.swaylock-security-key;
assert c.security.pam.services.sudo.u2f.enable && off.security.pam.services.sudo.u2f.enable;
assert c.security.pam.services.sudo-i.u2f.enable && off.security.pam.services.sudo-i.u2f.enable;
assert c.security.pam.services.sudo.u2f.control == "sufficient";
assert !c.security.pam.u2f.enable && !off.security.pam.u2f.enable;
assert !c.security.pam.services.swaylock.u2f.enable;
assert !(off.security.pam.services ? swaylock-key);
assert lib.hasInfix "auth required" c.security.pam.services.swaylock-key.text;
assert lib.hasInfix "userpresence=1 pinverification=0 userverification=0"
  c.security.pam.services.swaylock-key.text;
assert !(lib.hasInfix "pam_permit" c.security.pam.services.swaylock-key.text);
assert !(lib.hasInfix "nouserok" c.security.pam.services.swaylock-key.text);
assert c.security.pam.u2f.settings.authfile == "/etc/security/flakes-u2f-keys";
assert off.security.pam.u2f.settings.origin == "pam://keke-flakes";
assert
  c.home-manager.users.keke.programs.swaylock.settings.image
  == "${import ../NixOS/desktop/wallpaper.nix}";
assert builtins.getContext c.home-manager.users.keke.programs.swaylock.settings.image != { };
assert c.home-manager.users.keke.systemd.user.services ? snipaste;
assert lib.hasInfix "screenshot-path null" (builtins.readFile ../NixOS/desktop/niri/config.kdl);
assert !off.home-manager.users.keke.programs.ghostty.enable;
assert !off.home-manager.users.keke.programs.wezterm.enable;
assert c.home-manager.users.keke.programs.ghostty.enable;
assert !c.home-manager.users.keke.programs.wezterm.enable;
assert !(c.home-manager.users.keke.programs.ghostty.settings ? background-blur);
assert lib.hasInfix ''spawn "ghostty"'' (builtins.readFile ../NixOS/desktop/niri/config.kdl);
assert !off.home-manager.users.keke.programs.obsidian.enable;
assert builtins.elem enabled.pkgs.python3Packages.playwright c.my.pythonExtraPackages;
assert builtins.elem enabled.pkgs.python3Packages.playwright-stealth c.my.pythonExtraPackages;
assert off.my.pythonExtraPackages == [ ];
assert !(off.environment.variables ? PLAYWRIGHT_BROWSERS_PATH);
assert
  c.environment.variables.PLAYWRIGHT_BROWSERS_PATH
  == "${enabled.pkgs.python3Packages.playwright.driver.selectBrowsers {
    withFirefox = false;
    withWebkit = false;
    withChromiumHeadlessShell = true;
  }}";
assert !(off.home-manager.users.keke.home.file ? ".local/share/emacs-rime-native");
assert c.my.desktop.niri.extraConfig == "" && c.my.desktop.niri.outputs == "";
assert lib.all (font: builtins.elem (toString font) (map toString c.fonts.packages)) [
  enabled.pkgs.dejavu_fonts
  enabled.pkgs.nerd-fonts.symbols-only
];
assert !(builtins.elem (toString enabled.pkgs.lxgw-wenkai) (map toString c.fonts.packages));
assert !(builtins.elem (toString disabled.pkgs.lxgw-wenkai) (map toString off.fonts.packages));
assert lib.any (font: (font.pname or "") == "monolisa-nasy") c.fonts.packages;
assert !lib.any (font: (font.pname or "") == "monolisa-nasy") off.fonts.packages;
assert lib.any (font: (font.pname or "") == "tsanger-jinkai-05") c.fonts.packages;
assert !lib.any (font: (font.pname or "") == "tsanger-jinkai-05") off.fonts.packages;
assert
  c.fonts.fontconfig.defaultFonts.sansSerif == [
    "MonoLisa Nasy"
    "TsangerJinKai05"
  ];
assert
  c.fonts.fontconfig.defaultFonts.monospace == [
    "MonoLisa Nasy"
    "TsangerJinKai05"
  ];
assert builtins.elem "仓耳今楷05 W03" c.home-manager.users.keke.programs.ghostty.settings.font-family;
assert lib.hasInfix "仓耳今楷05 W03" c.home-manager.users.keke.programs.emacs.extraConfig;
assert !(c.systemd.services ? openlist) && !(off.systemd.services ? openlist);
assert deck.config.systemd.services.openlist.enable;
assert deck.config.systemd.services.openlist.serviceConfig.WorkingDirectory == "/home/keke";
assert c.home-manager.users.keke.gtk.font.name == "sans-serif";
assert
  c.home-manager.users.keke.dconf.settings."org/gnome/desktop/interface".font-name == "sans-serif 11";
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
    lockWallpaper = c.home-manager.users.keke.programs.swaylock.settings.image;
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
    # Realize and retain the PNG itself, not a discarded source-tree string.
    test -s "$lockWallpaper"
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
