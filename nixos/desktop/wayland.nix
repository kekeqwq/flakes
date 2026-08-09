{
  config,
  pkgs,
  lib,
  ...
}:
{

  security.polkit.enable = true;

  programs.niri.enable = true;

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
    xwayland-satellite
    wev
    wlr-randr
    # wf-recorder
    swaybg
    wl-clipboard
    grim
    slurp
    qimgv
    rofi
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
        margin-left = 200;
        margin-right = 200;
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
          spacing = 12;
        };
        battery = {
          format = "{capacity}% 󱊣";
          format-charging = "{capacity}% 󰂄";
          interval = 1;
          on-click = "/home/keke/.config/rofi/power.sh";
        };
      };
    };
    style = ''
      * {
          font-size: 15px;
      }
      window#waybar {
          border-bottom: 1px solid #181825;
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
          background-color: rgba(50, 50, 50, 0.5);
          color: #ffffff;
      }

      #workspaces button.active {
          background: #5e81ac;
      }

      #workspaces button.urgent {
          background-color: #fb4934;
          animation: urgentBlink 1s linear infinite alternate;
      }

      #clock{
          font-size: 16px;
      }

      #tray {
          padding: 0px 4px;
      }

      #backlight {
          color: #8fbcbb;
      }
      #pulseaudio {
          color: #88c0d0;
      }

      #battery {
          color: #81a1c1;
      }



      .modules-left,
      .modules-right,
      .modules-center {
          padding: 4px 0px;
      }
    '';
  };
}
