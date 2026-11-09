{
  lib,
  ...
}:
{
  myuser.hm.programs.wezterm = {
    enable = true;

    # 静态项：HM 用 toLua 写进 wezterm.lua
    settings = {
      initial_cols = 120;
      initial_rows = 28;
      font = lib.generators.mkLuaInline ''
        wezterm.font_with_fallback({
                "MonoLisa Nasy",
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

      -- Let the bar see the initial scheme before it derives tab colors.
      local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
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
