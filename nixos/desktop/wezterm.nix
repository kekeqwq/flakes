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
      font = lib.generators.mkLuaInline ''wezterm.font("MonoLisa Nasy")'';
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

      local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
      bar.apply_to_config(config)

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
      end

      if wezterm.target_triple == "x86_64-unknown-linux-gnu" then
        config.enable_kitty_graphics = true
        config.term = "xterm-kitty"
        config.color_scheme = "Catppuccin Mocha"
        config.font_size = 12
      end
    '';
  };
}
