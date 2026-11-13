{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Keep the currently used version; updating the plugin is a separate change.
  barSrc = pkgs.fetchFromGitHub {
    owner = "adriankarlen";
    repo = "bar.wezterm";
    rev = "af6642a004942d6b58b777d002cb7ee82ca94872";
    hash = "sha256-7FJfDV3X3Xi799dRXO7zT+Zid5EBfLMVIFmB3g013cU=";
  };
  barPlugin =
    pkgs.runCommand "wezterm-bar-af6642a"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        mkdir -p "$out"
        cp -r ${barSrc}/plugin/. "$out/"
        cp ${barSrc}/LICENSE "$out/LICENSE"
        chmod -R u+w "$out"
        # Upstream discovers modules through the mutable plugin cache. Replace
        # that loader only; modules are now next to init.lua, supplied by Nix.
        python3 - "$out/init.lua" <<'PY'
        import pathlib, sys
        path = pathlib.Path(sys.argv[1])
        text = path.read_text()
        start = text.index('local separator =')
        end = text.index('local utilities = require "bar.utilities"', start)
        path.write_text(text[:start] + text[end:])
        PY
      '';
in
{
  myuser.hm.xdg.configFile = {
    "wezterm/bar".source = barPlugin;
    "wezterm/input-method.lua".source = ../input-method/wezterm.lua;
  };

  myuser.hm.programs.wezterm = {
    enable = true;

    # 静态项：HM 用 toLua 写进 wezterm.lua
    settings = {
      initial_cols = 120;
      initial_rows = 28;
      font = lib.generators.mkLuaInline ''
        wezterm.font_with_fallback({
                "MonoLisa Nasy",
                -- Shared Nix-managed fallback for Starship arrows and symbols.
                "DejaVu Sans Mono",
                "Symbols Nerd Font Mono",
                "Noto Sans Symbols 2",
                "LXGW WenKai Mono",
              })'';
      window_background_opacity = 0.8;
      window_decorations = "RESIZE";
      window_close_confirmation = "NeverPrompt";
      window_padding = {
        left = 1;
        right = 1;
        top = 1;
        bottom = 1;
      };
    };

    # 运行时才能做的事（系统外观、插件、三端 target_triple）
    # 必须留在 extraConfig，否则 NixOS 构建再 scp 到 Windows 会丢掉 pwsh 分支
    extraConfig = ''
      local function scheme_for_appearance(appearance)
        if appearance:find("Dark") then
          return "Catppuccin Mocha"
        else
          return "Catppuccin Latte"
        end
      end

      if wezterm.target_triple == "x86_64-pc-windows-msvc" then
        config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
        config.default_prog = {
          [[C:\Users\keke\Downloads\pwsh\pwsh.exe]],
          "-NoLogo",
        }
        config.default_domain = "local"
        config.wsl_domains = {}
        config.font_size = 12
        config.prefer_egl = false
        config.keys = config.keys or {}
        table.insert(config.keys, {
          key = "d",
          mods = "CTRL",
          action = wezterm.action.SendString("\x04"),
        })
      end

      if wezterm.target_triple == "aarch64-apple-darwin" then
        config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
        config.font_size = 16
        config.default_prog = { "/run/current-system/sw/bin/fish", "-l" }
      end

      if wezterm.target_triple == "x86_64-unknown-linux-gnu" then
        config.enable_kitty_graphics = true
        config.term = "xterm-kitty"
        config.color_scheme = "Catppuccin Mocha"
        config.font_size = 12
      end

      -- Report the focused pane for the input-method switcher on macOS and
      -- Linux. The reporter only writes metadata; it never switches sources.
      if wezterm.target_triple == "aarch64-apple-darwin"
        or wezterm.target_triple == "x86_64-unknown-linux-gnu" then
        local imeConfig = wezterm.config_dir .. "/input-method.lua"
        wezterm.add_to_config_reload_watch_list(imeConfig)
        dofile(imeConfig).apply()

        -- Tell the switcher before tmux sees the prefix. Spawning is
        -- asynchronous, so tmux's own prefix handling is never delayed.
        local prefix = '${config.my.inputMethod.prefixCommand}'
        if prefix ~= "" then
          config.keys = config.keys or {}
          for _, keyspec in ipairs({
            { key = 'b', mods = 'CTRL' },
            { key = 'Space', mods = 'CTRL' },
          }) do
            table.insert(config.keys, {
              key = keyspec.key,
              mods = keyspec.mods,
              action = wezterm.action_callback(function(window, pane)
                wezterm.background_child_process({ prefix, 'begin' })
                window:perform_action(
                  wezterm.action.SendKey { key = keyspec.key, mods = keyspec.mods },
                  pane
                )
              end),
            })
          end
        end
      end

      -- Let the bar see the initial scheme before it derives tab colors.
      local bar_dir = wezterm.config_dir .. "/bar"
      package.path = bar_dir .. "/?.lua;" .. package.path
      local bar = dofile(bar_dir .. "/init.lua")
      bar.apply_to_config(config)

      if wezterm.target_triple == "aarch64-apple-darwin"
        or wezterm.target_triple == "x86_64-pc-windows-msvc" then
        local last_tmux_theme = nil
        local last_tmux_sync = 0
        local function sync_tmux_theme(appearance)
          if wezterm.target_triple ~= "aarch64-apple-darwin" then return end
          local theme = appearance:find("Dark") and "dark" or "light"
          local now = os.time()
          if now - last_tmux_sync < 5 then
            return
          end
          last_tmux_sync = now
          local ok, success = pcall(wezterm.run_child_process, {
            wezterm.home_dir .. "/.config/tmux/apply-theme",
            theme,
          })
          if ok and success then
            last_tmux_theme = theme
          end
        end

        local function sync_appearance(window)
          local appearance = window:get_appearance()
          local scheme = scheme_for_appearance(appearance)
          local overrides = window:get_config_overrides() or {}
          if overrides.color_scheme ~= scheme or overrides.colors ~= nil then
            overrides.color_scheme = scheme
            -- bar.wezterm stores a full resolved palette here. Keeping it would
            -- mask the new scheme; let its reload handler rebuild it instead.
            overrides.colors = nil
            window:set_config_overrides(overrides)
          end
          sync_tmux_theme(appearance)
        end

        -- Native appearance notifications; the equality guard avoids reload loops.
        wezterm.on("window-config-reloaded", sync_appearance)
        -- Lightweight fallback for a missed notification; no shell/subprocess.
        wezterm.on("update-status", sync_appearance)
      end
    '';
  };
}
