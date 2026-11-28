{
  config,
  pkgs,
  lib,
  ...
}:
let
  wallpaper = import ./wallpaper-runtime.nix { inherit config pkgs lib; };
  appearance = config.my.desktop.appearance;
  hm = config.home-manager.users.${config.myuser.name};
  paint = import ./appearance-palette.nix;
  selected = name: hm.lib.file.mkOutOfStoreSymlink "${appearance.root}/current/${name}";
  displayWallpaper = pkgs.writeShellScript "display-wallpaper" ''
    ${wallpaper.resolve}
    exec ${pkgs.swaybg}/bin/swaybg -i "$image" -m fill
  '';
  iconTheme = mode: if mode == "light" then "Papirus-Light" else "Papirus-Dark";
  trayIcons = mode: "${hm.gtk.iconTheme.package}/share/icons/${iconTheme mode}/22x22/panel";
  accentFor = import ./appearance-accent.nix;
  # The CSS border and Niri shadow cutout must share a radius.
  waybarRadius = "12";
  mediaNotify = pkgs.writeShellApplication {
    name = "keke-media-notify";
    runtimeInputs = with pkgs; [
      wireplumber
      brightnessctl
      libnotify
      util-linux
      systemd
      gawk
    ];
    text = builtins.readFile ./media-notify.sh;
  };
  niriConfig =
    mode:
    pkgs.writeText "niri-${mode}-unchecked.kdl" (
      paint mode (
        config.my.desktop.niri.outputs
        + config.my.desktop.niri.extraConfig
        +
          builtins.replaceStrings
            [ "    // SNIPASTE_BINDINGS" "@WAYBAR_RADIUS@" "@MEDIA_NOTIFY@" ''active-color "#cba6f7"'' ]
            [
              (lib.optionalString pkgs.stdenv.hostPlatform.isx86_64 ''
                F3 hotkey-overlay-title="Pin clipboard with Snipaste" {
                    spawn "${lib.getExe (import ./pin-clipboard.nix { inherit pkgs; })}"
                }
              '')
              waybarRadius
              (lib.getExe mediaNotify)
              ''active-color "${(accentFor mode).fill}"''
            ]
            (builtins.readFile ./niri/config.kdl)
      )
    );
  # Both complete variants include the host's existing output layout and binds.
  checkedNiriConfig =
    mode:
    pkgs.runCommand "niri-${mode}-config.kdl" { nativeBuildInputs = [ pkgs.niri ]; } ''
      niri validate -c ${niriConfig mode}
      cp ${niriConfig mode} "$out"
    '';
  panel = pkgs.keke-waybar-panel;
  clockStatus = pkgs.writeShellScript "waybar-clock" ''
    exec ${pkgs.coreutils}/bin/date '+%I:%M %p' | ${pkgs.gnused}/bin/sed 's/^0//'
  '';
  networkStatus = pkgs.writeShellScript "waybar-network" (
    builtins.replaceStrings
      [ "@NMCLI@" "@IW@" "@AWK@" ]
      [ "${pkgs.networkmanager}/bin/nmcli" "${pkgs.iw}/bin/iw" "${pkgs.gawk}/bin/awk" ]
      (builtins.readFile ./waybar/network-status.sh)
  );

  waybarCSS = ''
    * {
        font-size: 14px;
        min-height: 0;
    }

    window#waybar {
        background: rgba(30, 30, 46, 0.94);
        color: #cdd6f4;
        border: 1px solid #45475a;
        border-radius: ${waybarRadius}px;
    }

    .modules-left,
    .modules-right,
    .modules-center {
        padding: 4px 6px;
    }

    #workspaces {
        margin-left: 4px;
    }

    #workspaces button {
        padding: 0;
        min-width: 28px;
        min-height: 28px;
        margin: 0 2px;
        border: none;
        box-shadow: none;
        border-radius: 6px;
        color: #a6adc8;
        background: transparent;
    }

    #workspaces button label {
        padding: 0;
        margin: 0;
        /* Waybar packs labels without expansion: the label itself must
           occupy the full square, otherwise its glyph stays left-aligned. */
        min-width: 28px;
        min-height: 28px;
    }

    #workspaces button:hover {
        background-color: #313244;
        color: #cdd6f4;
    }

    #workspaces button.active {
        background: @appearance_accent;
        color: @appearance_on_accent;
    }

    #workspaces button.urgent {
        background-color: #f38ba8;
        color: #1e1e2e;
    }

    #window {
        color: #a6adc8;
        margin-left: 6px;
    }

    #clock,
    #tray,
    #backlight,
    #wireplumber,
    #custom-network,
    #bluetooth,
    #battery,
    #custom-control-center {
        background: #313244;
        color: #cdd6f4;
        border: 1px solid #45475a;
        border-radius: 8px;
        padding: 3px 9px;
        margin-left: 6px;
    }

    #custom-clock {
        background: #313244;
        color: @appearance_accent_text;
        font-weight: 600;
        border: 1px solid #45475a;
        border-radius: 8px;
        padding: 3px 11px;
    }

    #custom-control-center {
        color: @appearance_accent_text;
        padding: 3px 11px;
    }

    #backlight {
        color: #f9e2af;
    }

    #wireplumber {
        color: #89b4fa;
    }

    #custom-network {
        color: #94e2d5;
    }

    #bluetooth {
        color: #b4befe;
    }

    #battery {
        color: #a6e3a1;
    }

    #battery.charging {
        color: #f9e2af;
        animation: battery-charge 2s ease-in-out infinite alternate;
    }

    #battery.low {
        color: #f38ba8;
    }

    @keyframes battery-charge {
        from { color: #f9e2af; }
        to { color: #a6e3a1; }
    }

    #tray {
        padding: 3px 8px;
    }

    /* Waybar renders named SNI symbolic icons with the item's CSS foreground.
       Don't substitute fixed icons for Telegram or the input method. */
    #tray > * {
        color: #cdd6f4;
    }

    tooltip {
        background: #1e1e2e;
        border: 1px solid #45475a;
        border-radius: 10px;
        color: #cdd6f4;
    }
  '';

  makoConfig = ''
    anchor=top-right
    layer=overlay
    outer-margin=12,12,0,0
    margin=0,0,8,0
    padding=10,14
    width=320
    border-radius=12
    border-size=1
    background-color=#1e1e2ef5
    text-color=#cdd6f4
    border-color=#45475a
    default-timeout=5000
    max-visible=4

    [urgency=critical]
    border-color=#f38ba8

    [app-name=keke-media]
    format=<b>%s</b>
    progress-color=over #cba6f755
    border-color=#cba6f7
    max-icon-size=22
    actions=0
    history=0
    default-timeout=1350
  '';

in
{
  my.desktop.appearance.files = lib.genAttrs [ "light" "dark" ] (mode: {
    "niri.kdl" = checkedNiriConfig mode;
    "rofi.rasi" = pkgs.writeText "rofi-${mode}.rasi" (
      ''configuration { icon-theme: "${iconTheme mode}"; }''
      + "\n"
      + paint mode (
        builtins.replaceStrings [ "#cba6f7" "text-color: @bg;" ] (
          if mode == "light" then
            [
              (accentFor mode).fill
              "text-color: ${(accentFor mode).onFill};"
            ]
          else
            [
              "#cba6f7"
              "text-color: @bg;"
            ]
        ) (builtins.readFile ./rofi-mocha.rasi)
      )
    );
    "mako.conf" = pkgs.writeText "mako-${mode}.conf" (
      paint mode (builtins.replaceStrings [ "#cba6f7" ] [ (accentFor mode).fill ] makoConfig)
    );
    "waybar.css" = pkgs.writeText "waybar-${mode}.css" ''
      @define-color appearance_accent ${(accentFor mode).fill};
      @define-color appearance_on_accent ${(accentFor mode).onFill};
      @define-color appearance_accent_text ${(accentFor mode).text};
      ${paint mode waybarCSS}
    '';
    "tray-qbittorrent.svg" = "${trayIcons mode}/qbittorrent-tray.svg";
    "tray-sunshine.svg" = "${trayIcons mode}/simplescreenrecorder-panel.svg";
  });
  myuser.hm.programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    settings = {
      modi = "drun";
      show-icons = true;
      matching = "fuzzy";
      sort = true;
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "Apps";
      display-run = "Run";
      display-window = "Windows";
    };
    theme = "keke-appearance";
  };

  security.polkit.enable = true;

  programs.niri = {
    enable = true;
    package = import ./niri/session-package.nix { inherit pkgs; };
  };
  # Validate again before Home Manager changes any files.
  myuser.hm.home.activation.validateNiriConfig = {
    after = [ ];
    before = [
      "checkLinkTargets"
      "writeBoundary"
    ];
    data = ''
      ${pkgs.niri}/bin/niri validate -c ${niriConfig "dark"}
    '';
  };
  myuser.hm.xdg.dataFile."rofi/themes/keke-appearance.rasi".source = selected "rofi.rasi";
  myuser.hm.xdg.configFile = {
    "niri/config.kdl" = {
      source = checkedNiriConfig "dark";
      force = true; # Replace the old hand-edited file with the Nix-managed symlink.
    };
  };
  myuser.hm.systemd.user.services.wallpaper = {
    Unit = {
      Description = "Current desktop wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = displayWallpaper;
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.wayfire = {
    enable = false;
    plugins = with pkgs.wayfirePlugins; [
      wcm
      wf-shell
      wayfire-plugins-extra
    ];
  };

  environment.systemPackages = with pkgs; [
    # Popup panels behind the Waybar modules.
    keke-waybar-panel
    brightnessctl
    playerctl
    # Niri need statllite
    xwayland-satellite
    wev
    wlr-randr
    # wf-recorder
    swaybg
    wl-clipboard
    grim
    slurp
    qimgv
  ];

  #hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };

  myuser.hm.xdg.configFile."mako/config".source = selected "mako.conf";
  # Use the same bus name for ordinary application notices and the media OSD.
  systemd.user.services.mako = {
    description = "Wayland desktop notifications";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "dbus";
      BusName = "org.freedesktop.Notifications";
      ExecCondition = "${pkgs.runtimeShell} -c 'test -n \"$WAYLAND_DISPLAY\"'";
      ExecStart = lib.getExe pkgs.mako;
      ExecReload = "${lib.getExe' pkgs.mako "makoctl"} reload";
    };
  };

  myuser.hm.programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;
        spacing = 0;
        margin-top = 12;
        margin-bottom = 5;
        margin-left = 12;
        margin-right = 12;
        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];
        "niri/window" = {
          format = "{}";
          max-length = 36;
          tooltip = true;
        };
        modules-center = [
          "custom/clock"
        ];
        modules-right = [
          "tray"
          "custom/network"
          "wireplumber"
          "backlight"
          "bluetooth"
          "battery"
          "custom/control-center"
        ];

        "custom/control-center" = {
          format = "";
          tooltip-format = "Control Center";
          on-click = "${panel}/bin/keke-waybar-panel control";
        };

        "custom/clock" = {
          exec = "${clockStatus}";
          interval = 5;
          # Calendar belongs to our click popup, not the custom module's
          # unsupported {calendar} tooltip formatter.
          tooltip = false;
          on-click = "${panel}/bin/keke-waybar-panel clock";
          on-click-right = "${panel}/bin/keke-waybar-panel clock";
        };

        backlight = {
          format = "{icon}";
          format-icons = [
            "󰃞"
            "󰃟"
            "󰃠"
          ];
          tooltip-format = "Brightness";
          on-click = "${panel}/bin/keke-waybar-panel brightness";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set +5%";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight set 5%-";
        };

        wireplumber = {
          format = "{icon}";
          format-muted = "󰝟";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          tooltip-format = "{node_name}";
          scroll-step = 5;
          on-click = "${panel}/bin/keke-waybar-panel audio";
        };

        "custom/network" = {
          exec = "${networkStatus}";
          interval = 2;
          on-click = "${panel}/bin/keke-waybar-panel network";
        };

        bluetooth = {
          format = "󰂯 0";
          format-on = "󰂯 0";
          format-off = "󰂲 0";
          format-disabled = "󰂲 0";
          format-no-controller = "󰂲 0";
          format-connected = "󰂱 {num_connections}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "${panel}/bin/keke-waybar-panel bluetooth";
        };

        battery = {
          interval = 5;
          format = "{icon} {capacity}%";
          format-icons = [
            "󱊡"
            "󱊢"
            "󱊣"
          ];
          format-charging = "󰂄 {capacity}%";
          format-full = "󰁹 {capacity}%";
          format-discharging-low = "󰂎 {capacity}%";
          format-not-charging-low = "󰂎 {capacity}%";
          states.low = 15;
        };

        tray = {
          icon-size = 17;
          spacing = 8;
          # These apps publish pixmaps instead of themed icon names. Override by
          # their actual StatusNotifierItem IDs; keep Telegram's dynamic states.
          icons = {
            qBittorrent = "${appearance.root}/current/tray-qbittorrent.svg";
            Sunshine = "${appearance.root}/current/tray-sunshine.svg";
          };
        };
      };
    };
    style = ''@import url("${appearance.root}/current/waybar.css");'';
  };
}
