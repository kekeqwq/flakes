{ pkgs, ... }:

{
  myuser.hm.programs.zellij = {
    enable = true;

    settings = {
      default_shell = "fish";
      default_layout = "wez";
      theme = "catppuccin-mocha";
      theme_dark = "catppuccin-mocha";
      theme_light = "catppuccin-latte";
      pane_frames = false;
      simplified_ui = false;
      default_mode = "normal";
      mouse_mode = true;
      copy_on_select = true;
      scroll_buffer_size = 10000;
      show_startup_tips = false;
      show_release_notes = false;
      session_serialization = false;
      on_force_close = "detach";

      ui.pane_frames.hide_session_name = true;

      # Windows 解开下面两行；NixOS/mac 保持注释，用 $SHELL
      # default_shell = "C:/Users/keke/Downloads/pwsh/pwsh.exe";
      # post_command_discovery_hook = "echo C:/Users/keke/Downloads/pwsh/pwsh.exe";

      plugins = {
        compact-bar._props.location = "zellij:compact-bar";
        tab-bar._props.location = "zellij:tab-bar";
        status-bar._props.location = "zellij:status-bar";
        session-manager._props.location = "zellij:session-manager";
      };

      # 只保留 Ctrl+b 前缀；其它模式清空默认绑定，避免 Ctrl+g/q/p 等被 Zellij 吃掉
      keybinds._children = [
        {
          normal = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Ctrl b" ];
                  SwitchToMode._args = [ "Tmux" ];
                };
              }
            ];
          };
        }

        {
          tmux = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [
                    "Ctrl b"
                    "b"
                  ];
                  _children = [
                    { Write._args = [ 2 ]; }
                    { SwitchToMode._args = [ "Normal" ]; }
                  ];
                };
              }
              {
                bind = {
                  _args = [ "c" ];
                  _children = [
                    { NewTab = { }; }
                    { SwitchToMode._args = [ "Normal" ]; }
                  ];
                };
              }
              {
                bind = {
                  _args = [ "n" ];
                  _children = [
                    { GoToNextTab = { }; }
                    { SwitchToMode._args = [ "Normal" ]; }
                  ];
                };
              }
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }

        {
          locked = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Ctrl b" ];
                  SwitchToMode._args = [ "Tmux" ];
                };
              }
            ];
          };
        }

        {
          pane = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          tab = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          resize = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          move = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          scroll = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          session = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          search = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          entersearch = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }
        {
          renametab = {
            _props.clear-defaults = true;
            _children = [
              {
                bind = {
                  _args = [ "Esc" ];
                  SwitchToMode._args = [ "Normal" ];
                };
              }
            ];
          };
        }

        {
          shared_except = {
            _args = [ "tmux" ];
            _children = [
              {
                bind = {
                  _args = [ "Ctrl b" ];
                  SwitchToMode._args = [ "Tmux" ];
                };
              }
            ];
          };
        }
      ];
    };

    layouts.wez = ''
      layout {
          default_tab_template {
              children
              pane size=1 borderless=true {
                  plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                      format_left   ""
                      format_center "{mode} {tabs}"
                      format_right  ""
                      format_space  ""

                      hide_frame_for_single_pane "true"
                      border_enabled "false"

                      mode_normal        ""
                      mode_tmux          "#[fg=#1e66f5]  "
                      mode_locked        "#[fg=#d20f39]  "
                      mode_scroll        "#[fg=#1e66f5] 󰈈 "
                      mode_pane          "#[fg=#179299]  "
                      mode_tab           "#[fg=#8839ef] 󰓩 "
                      mode_resize        "#[fg=#df8e1d] 󰁂 "
                      mode_move          "#[fg=#04a5e5] 󰆾 "
                      mode_session       "#[fg=#ea76cb] 󰆍 "
                      mode_search        "#[fg=#1e66f5]  "
                      mode_enter_search  "#[fg=#1e66f5]  "
                      mode_rename_tab    "#[fg=#8839ef] 󰑕 "
                      mode_rename_pane   "#[fg=#179299] 󰑕 "

                      tab_normal              "#[fg=#5c5f77] {index} → {name} "
                      tab_normal_fullscreen   "#[fg=#5c5f77] {index} → {name} 󰊓 "
                      tab_normal_sync         "#[fg=#5c5f77] {index} → {name} 󰓦 "
                      tab_active              "#[fg=#1e66f5,bold] {index} → {name} "
                      tab_active_fullscreen   "#[fg=#1e66f5,bold] {index} → {name} 󰊓 "
                      tab_active_sync         "#[fg=#1e66f5,bold] {index} → {name} 󰓦 "
                      tab_separator           ""
                      tab_rename              "#[fg=#df8e1d] {index} → {name} "
                  }
              }
          }
      }
    '';
  };
}
