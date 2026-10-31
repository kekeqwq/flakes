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
    lib.optionalString (config.networking.hostName == "deck") (
      builtins.readFile ../../hosts/deck/outputs.kdl
    )
    + builtins.readFile ./niri/config.kdl
  );
  # Validate the exact complete configuration installed by Home Manager.
  checkedNiriConfig = pkgs.runCommand "niri-config.kdl" { nativeBuildInputs = [ pkgs.niri ]; } ''
    niri validate -c ${niriConfig}
    cp ${niriConfig} "$out"
  '';
in
{
  systemd.services.kikibridge-rx = {
    description = "KikiBridge UDP → uinput receiver";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kikibridge-rx}/bin/kikibridge-rx";
      Restart = "always";
      RestartSec = 2;
      DeviceAllow = [ "/dev/uinput rw" ];
    };
  };

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
    # Niri need statllite
    wezterm
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
          "niri/window"
        ];
        modules-center = [
          "clock"
        ];
        modules-right = [
          "tray"
          "backlight"
          "pulseaudio"
          "battery"
        ];
        pulseaudio = {
          format = "{volume}% 󰝚";
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        };
        backlight = {
          format = "{percent}% 󰌵";
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
        battery = {
          format = "{capacity}% 󱊣";
          format-charging = "{capacity}% 󰂄";
          interval = 1;
          on-click = "${pkgs.rofi}/bin/rofi -show run";
        };
      };
    };
    style = ''
      * {
          font-size: 15px;
      }
      window#waybar {
          background: rgba(30, 30, 46, 0.95);
          color: #cdd6f4;
          border: 1px solid #45475a;
          border-radius: 10px;
      }


      #clock,
      #tray,
      #battery,
      #cpu,
      #window,
      #memory,
      #network,
      #scratchpad,
      #temperature,
      #pulseaudio,
      #backlight {
          background: transparent;
          padding: 0px 0px;
          border-radius: 6px;
          margin: 0px;
          margin-top: 0px;
          margin-bottom: 0px;
          margin-right: 14px;
      }

      #workspaces {
          margin-left: 5px;
      }

      #workspaces button {
          padding: 0 5px;
          margin-right: 1px;
          border-radius: 4px;
      }

      #workspaces button:hover {
          background-color: #45475a;
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

      #clock{
          font-size: 16px;
      }

      #tray {
          padding: 0px 4px;
      }

      #backlight {
          color: #f9e2af;
      }
      #pulseaudio {
          color: #89dceb;
      }

      #battery {
          color: #a6e3a1;
      }



      .modules-left,
      .modules-right,
      .modules-center {
          padding: 4px 0px;
      }
    '';
  };
}
