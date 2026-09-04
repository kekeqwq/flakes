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
      session_serialization = true;

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
              {
                bind = {
                  _args = [ "Ctrl g" ];
                  SwitchToMode._args = [ "Locked" ];
                };
              }
              {
                bind = {
                  _args = [ "Ctrl q" ];
                  Quit = { };
                };
              }
            ];
          };
        }

        {
          locked._children = [
            {
              bind = {
                _args = [ "Ctrl g" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
            {
              bind = {
                _args = [ "Ctrl b" ];
                SwitchToMode._args = [ "Tmux" ];
              };
            }
          ];
        }

        {
          tmux._children = [
            {
              bind = {
                _args = [ "Ctrl b" ];
                _children = [
                  { Write._args = [ 2 ]; }
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
                _args = [ "p" ];
                _children = [
                  { GoToPreviousTab = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "1" ];
                _children = [
                  { GoToTab._args = [ 1 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "2" ];
                _children = [
                  { GoToTab._args = [ 2 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "3" ];
                _children = [
                  { GoToTab._args = [ 3 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "4" ];
                _children = [
                  { GoToTab._args = [ 4 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "5" ];
                _children = [
                  { GoToTab._args = [ 5 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "6" ];
                _children = [
                  { GoToTab._args = [ 6 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "7" ];
                _children = [
                  { GoToTab._args = [ 7 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "8" ];
                _children = [
                  { GoToTab._args = [ 8 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "9" ];
                _children = [
                  { GoToTab._args = [ 9 ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "\"" ];
                _children = [
                  { NewPane._args = [ "Down" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "%" ];
                _children = [
                  { NewPane._args = [ "Right" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "x" ];
                _children = [
                  { CloseFocus = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "z" ];
                _children = [
                  { ToggleFocusFullscreen = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "[" ];
                SwitchToMode._args = [ "Scroll" ];
              };
            }
            {
              bind = {
                _args = [ "," ];
                _children = [
                  { SwitchToMode._args = [ "RenameTab" ]; }
                  { TabNameInput._args = [ 0 ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "d" ];
                Detach = { };
              };
            }
            {
              bind = {
                _args = [ "&" ];
                _children = [
                  { CloseTab = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [
                  "Left"
                  "h"
                ];
                _children = [
                  { MoveFocus._args = [ "Left" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [
                  "Right"
                  "l"
                ];
                _children = [
                  { MoveFocus._args = [ "Right" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [
                  "Down"
                  "j"
                ];
                _children = [
                  { MoveFocus._args = [ "Down" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [
                  "Up"
                  "k"
                ];
                _children = [
                  { MoveFocus._args = [ "Up" ]; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "o" ];
                _children = [
                  { FocusNextPane = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ ";" ];
                _children = [
                  { FocusLastPane = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
          ];
        }

        {
          scroll._children = [
            {
              bind = {
                _args = [
                  "Esc"
                  "q"
                  "Ctrl c"
                ];
                _children = [
                  { ScrollToBottom = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "e" ];
                _children = [
                  { EditScrollback = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [
                  "j"
                  "Down"
                ];
                ScrollDown = { };
              };
            }
            {
              bind = {
                _args = [
                  "k"
                  "Up"
                ];
                ScrollUp = { };
              };
            }
            {
              bind = {
                _args = [
                  "Ctrl f"
                  "PageDown"
                ];
                PageScrollDown = { };
              };
            }
            {
              bind = {
                _args = [
                  "Ctrl b"
                  "PageUp"
                ];
                PageScrollUp = { };
              };
            }
            {
              bind = {
                _args = [ "d" ];
                HalfPageScrollDown = { };
              };
            }
            {
              bind = {
                _args = [ "u" ];
                HalfPageScrollUp = { };
              };
            }
            {
              bind = {
                _args = [ "s" ];
                _children = [
                  { SwitchToMode._args = [ "EnterSearch" ]; }
                  { SearchInput._args = [ 0 ]; }
                ];
              };
            }
          ];
        }

        {
          search._children = [
            {
              bind = {
                _args = [
                  "Esc"
                  "Ctrl c"
                ];
                _children = [
                  { ScrollToBottom = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
            {
              bind = {
                _args = [ "n" ];
                Search._args = [ "down" ];
              };
            }
            {
              bind = {
                _args = [ "p" ];
                Search._args = [ "up" ];
              };
            }
            {
              bind = {
                _args = [
                  "j"
                  "Down"
                ];
                ScrollDown = { };
              };
            }
            {
              bind = {
                _args = [
                  "k"
                  "Up"
                ];
                ScrollUp = { };
              };
            }
          ];
        }

        {
          entersearch._children = [
            {
              bind = {
                _args = [
                  "Ctrl c"
                  "Esc"
                ];
                SwitchToMode._args = [ "Scroll" ];
              };
            }
            {
              bind = {
                _args = [ "Enter" ];
                SwitchToMode._args = [ "Search" ];
              };
            }
          ];
        }

        {
          renametab._children = [
            {
              bind = {
                _args = [ "Enter" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
            {
              bind = {
                _args = [
                  "Esc"
                  "Ctrl c"
                ];
                _children = [
                  { UndoRenameTab = { }; }
                  { SwitchToMode._args = [ "Normal" ]; }
                ];
              };
            }
          ];
        }

        {
          pane._children = [
            {
              bind = {
                _args = [ "Esc" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
          ];
        }

        {
          resize._children = [
            {
              bind = {
                _args = [ "Esc" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
          ];
        }

        {
          move._children = [
            {
              bind = {
                _args = [ "Esc" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
          ];
        }

        {
          tab._children = [
            {
              bind = {
                _args = [ "Esc" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
          ];
        }

        {
          session._children = [
            {
              bind = {
                _args = [ "Esc" ];
                SwitchToMode._args = [ "Normal" ];
              };
            }
            {
              bind = {
                _args = [ "d" ];
                Detach = { };
              };
            }
          ];
        }

        {
          shared_except = {
            _args = [
              "tmux"
              "locked"
            ];
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
          shared_except = {
            _args = [ "locked" ];
            _children = [
              {
                bind = {
                  _args = [ "Ctrl g" ];
                  SwitchToMode._args = [ "Locked" ];
                };
              }
              {
                bind = {
                  _args = [ "Ctrl q" ];
                  Quit = { };
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
