{
  config,
  pkgs,
  lib,
  ...
}:
let
  wallpaper = ./wallpapers/mocha-mountains.png;
  trayIcons = "${
    config.home-manager.users.${config.myuser.name}.gtk.iconTheme.package
  }/share/icons/Papirus-Dark/22x22/panel";
  niriConfig = pkgs.writeText "niri-unchecked.kdl" (
    config.my.desktop.niri.outputs
    + config.my.desktop.niri.extraConfig
    + builtins.readFile ./niri/config.kdl
  );
  # Validate the exact complete configuration installed by Home Manager.
  checkedNiriConfig = pkgs.runCommand "niri-config.kdl" { nativeBuildInputs = [ pkgs.niri ]; } ''
    niri validate -c ${niriConfig}
    cp ${niriConfig} "$out"
  '';
  panel = pkgs.keke-waybar-panel;
  clockStatus = pkgs.writeShellScript "waybar-clock" ''
    exec ${pkgs.coreutils}/bin/date '+%I:%M %p' | ${pkgs.gnused}/bin/sed 's/^0//'
  '';
  brightnessStatus = pkgs.writeShellScript "waybar-brightness" ''
    level=$(${pkgs.brightnessctl}/bin/brightnessctl -m | ${pkgs.gawk}/bin/awk -F, '{print $4}')
    ${pkgs.coreutils}/bin/printf '󰃠 %s\n' "$level"
  '';
  audioStatus = pkgs.writeShellScript "waybar-audio" ''
    if ${pkgs.pulseaudio}/bin/pactl get-sink-mute @DEFAULT_SINK@ | ${pkgs.gnugrep}/bin/grep -q yes; then
      ${pkgs.coreutils}/bin/printf '󰝟 muted\n'
      exit 0
    fi
    level=$(${pkgs.pulseaudio}/bin/pactl get-sink-volume @DEFAULT_SINK@ |
      ${pkgs.gnugrep}/bin/grep -o '[0-9]\\+%' | ${pkgs.coreutils}/bin/head -1)
    ${pkgs.coreutils}/bin/printf '󰕾 %s\n' "$level"
  '';
  networkStatus = pkgs.writeShellScript "waybar-network" (
    builtins.replaceStrings
      [ "@NMCLI@" "@AWK@" ]
      [ "${pkgs.networkmanager}/bin/nmcli" "${pkgs.gawk}/bin/awk" ]
      (builtins.readFile ./waybar/network-status.sh)
  );
  bluetoothStatus = pkgs.writeShellScript "waybar-bluetooth" (
    builtins.replaceStrings
      [ "@BLUETOOTHCTL@" "@AWK@" ]
      [ "${pkgs.bluez}/bin/bluetoothctl" "${pkgs.gawk}/bin/awk" ]
      (builtins.readFile ./waybar/bluetooth-status.sh)
  );
  batteryStatus = pkgs.writeShellScript "waybar-battery" (
    builtins.readFile ./waybar/battery-status.sh
  );
in
{
  myuser.hm.programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    settings = {
      modi = "drun";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      matching = "fuzzy";
      sort = true;
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "Apps";
      display-run = "Run";
      display-window = "Windows";
    };
    theme = ./rofi-mocha.rasi;
  };

  security.polkit.enable = true;

  programs.niri.enable = true;
  # Validate again before Home Manager changes any files.
  myuser.hm.home.activation.validateNiriConfig = {
    after = [ ];
    before = [
      "checkLinkTargets"
      "writeBoundary"
    ];
    data = ''
      ${pkgs.niri}/bin/niri validate -c ${niriConfig}
    '';
  };
  myuser.hm.xdg.configFile = {
    "niri/config.kdl" = {
      source = checkedNiriConfig;
      force = true; # Replace the old hand-edited file with the Nix-managed symlink.
    };
  };
  myuser.hm.systemd.user.services.wallpaper = {
    Unit = {
      Description = "Catppuccin Mocha wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill";
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

  myuser.hm.programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 0;
        spacing = 0;
        margin-top = 12;
        margin-bottom = 5;
        margin-left = 12;
        margin-right = 12;
        modules-left = [
          "niri/workspaces"
        ];
        modules-center = [
          "custom/clock"
        ];
        modules-right = [
          "tray"
          "custom/bluetooth"
          "custom/network"
          "custom/audio"
          "custom/brightness"
          "custom/battery"
        ];

        "custom/clock" = {
          exec = "${clockStatus}";
          interval = 5;
          tooltip-format = "<tt>{calendar}</tt>";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#89b4fa'><b>{}</b></span>";
              days = "<span color='#cdd6f4'>{}</span>";
              weeks = "<span color='#a6adc8'><b>W{}</b></span>";
              today = "<span color='#cba6f7'><b><u>{}</u></b></span>";
            };
          };
          on-click = "${panel}/bin/keke-waybar-panel clock";
          on-click-right = "${panel}/bin/keke-waybar-panel clock";
        };

        "custom/brightness" = {
          exec = "${brightnessStatus}";
          interval = 3;
          on-click = "${panel}/bin/keke-waybar-panel brightness";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +5%";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        };

        "custom/audio" = {
          exec = "${audioStatus}";
          interval = 2;
          on-click = "${panel}/bin/keke-waybar-panel audio";
          on-scroll-up = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
          on-scroll-down = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
        };

        "custom/network" = {
          exec = "${networkStatus}";
          interval = 3;
          on-click = "${panel}/bin/keke-waybar-panel network";
        };

        "custom/bluetooth" = {
          exec = "${bluetoothStatus}";
          interval = 5;
          on-click = "${panel}/bin/keke-waybar-panel bluetooth";
        };

        "custom/battery" = {
          exec = "${batteryStatus}";
          interval = 5;
        };

        tray = {
          icon-size = 20;
          spacing = 10;
          # These apps publish pixmaps instead of themed icon names. Override by
          # their actual StatusNotifierItem IDs; keep Telegram's dynamic states.
          icons = {
            qBittorrent = "${trayIcons}/qbittorrent-tray.svg";
            Sunshine = "${trayIcons}/simplescreenrecorder-panel.svg";
          };
        };
      };
    };
    style = ''
      * {
          font-size: 14px;
          min-height: 0;
      }

      window#waybar {
          background: rgba(30, 30, 46, 0.96);
          color: #cdd6f4;
          border: 1px solid #45475a;
          border-radius: 12px;
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
          padding: 0 6px;
          margin-right: 2px;
          border-radius: 6px;
          color: #a6adc8;
          background: transparent;
      }

      #workspaces button:hover {
          background-color: #313244;
          color: #cdd6f4;
      }

      #workspaces button.active {
          background: #cba6f7;
          color: #1e1e2e;
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
      #custom-brightness,
      #custom-audio,
      #custom-network,
      #custom-bluetooth,
      #custom-battery {
          background: #313244;
          color: #cdd6f4;
          border-radius: 8px;
          padding: 4px 10px;
          margin-left: 6px;
      }

      #custom-clock {
          background: #313244;
          color: #cba6f7;
          font-weight: 600;
          border-radius: 8px;
          padding: 4px 12px;
      }

      #custom-brightness {
          color: #f9e2af;
      }

      #custom-audio {
          color: #89b4fa;
      }

      #custom-network {
          color: #94e2d5;
      }

      #custom-bluetooth {
          color: #b4befe;
      }

      #custom-battery {
          color: #a6e3a1;
      }

      #custom-battery.charging {
          color: #f9e2af;
      }

      #custom-battery.warning {
          color: #fab387;
      }

      #custom-battery.critical {
          color: #f38ba8;
      }

      #tray {
          padding: 4px 8px;
      }

      tooltip {
          background: #1e1e2e;
          border: 1px solid #45475a;
          border-radius: 10px;
          color: #cdd6f4;
      }
    '';
  };
}
