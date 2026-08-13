{
  config,
  pkgs,
  lib,
  ...
}:
let
  rofi-theme = pkgs.fetchFromGitHub {
    owner = "kekeqwq";
    repo = "rofi";
    rev = "b4f6e1d7a06986954beed4d1ba327d862c7dac6f";
    hash = "sha256-8/uqYUEEI5Tyz4padRLuqA9xC6g0hphE8R9NMavtQnU=";
  };
in
{
  myuser.hm.programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    extraConfig = {
      modi = "drun";
      show-icons = true;
      icon-theme = "Fluent";
      matching = "fuzzy";
      sort = true;
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "Apps";
      display-run = "Run";
      display-window = "Windows";
    };
    theme = "${rofi-theme}/catppuccin-default.rasi";
  };

  security.polkit.enable = true;

  programs.niri.enable = true;
  myuser.hm.home.file.".config/niri/config.kdl".text = ''
    include "/home/keke/Downloads/deck.kdl"
    input {
        mod-key "Alt"
    }
    output "DP-1" {
        mode "3840x2160@30"
        scale 2
        transform "normal"
    }
    layout {
        gaps 14
        center-focused-column "never"
        always-center-single-column
        default-column-display "tabbed"
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        default-column-width {
            proportion 0.5
        }
        preset-window-heights {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        focus-ring {
            width 3
            active-color "#d8dee9"
            inactive-color "rgba(0,0,0,0)"
        }
        shadow {
            on
            softness 10
            spread 10
            offset x=0 y=5
        }
        tab-indicator {
            off
        }
        insert-hint {
            color "#ffc87f80"
        }
    }
    spawn-at-startup "fcitx5"
    spawn-at-startup "swaybg" "-i" "/home/keke/Downloads/wall.jpg" "-m" "fill"
    prefer-no-csd
    layer-rule {
        match namespace="waybar"
        match namespace="rofi"
        match at-startup=true
        opacity 0.8
        shadow {
            on
            softness 10
            spread 10
            offset x=0 y=5
        }
        geometry-corner-radius 10
    }
    window-rule {
        geometry-corner-radius 6
        clip-to-geometry true
        draw-border-with-background false
    }
    binds {
        Mod+Return {
            spawn "wezterm"
        }
        Mod+D {
            spawn "rofi" "-show"
        }
        XF86AudioRaiseVolume allow-when-locked=true {
            spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"
        }
        XF86AudioLowerVolume allow-when-locked=true {
            spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"
        }
        Mod+M {
            maximize-column
        }
        Mod+Q {
            close-window
        }
        Mod+1 {
            focus-workspace 1
        }
        Mod+2 {
            focus-workspace 2
        }
        Mod+3 {
            focus-workspace 3
        }
        Mod+4 {
            focus-workspace 4
        }
        Mod+5 {
            focus-workspace 5
        }
        Mod+6 {
            focus-workspace 6
        }
        Mod+7 {
            focus-workspace 7
        }
        Mod+8 {
            focus-workspace 8
        }
        Mod+9 {
            focus-workspace 9
        }
        Mod+Ctrl+1 {
            move-column-to-workspace 1
        }
        Mod+Ctrl+2 {
            move-column-to-workspace 2
        }
        Mod+Ctrl+3 {
            move-column-to-workspace 3
        }
        Mod+Ctrl+4 {
            move-column-to-workspace 4
        }
        Mod+Ctrl+5 {
            move-column-to-workspace 5
        }
        Mod+Ctrl+6 {
            move-column-to-workspace 6
        }
        Mod+Ctrl+7 {
            move-column-to-workspace 7
        }
        Mod+Ctrl+8 {
            move-column-to-workspace 8
        }
        Mod+Ctrl+9 {
            move-column-to-workspace 9
        }
    }
  '';

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
