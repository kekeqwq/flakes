let
  # Mocha source literals mapped to semantic Latte counterparts. Alpha suffixes
  # in Niri/Mako are retained; one mapping is shared by all our UI surfaces.
  latte = {
    "#1e1e2e" = "#eff1f5";
    "#181825" = "#e6e9ef";
    "#11111b" = "#dce0e8";
    "#313244" = "#e6e9ef";
    "#45475a" = "#bcc0cc";
    "#585b70" = "#acb0be";
    "#cdd6f4" = "#4c4f69";
    "#a6adc8" = "#5c5f77";
    "#cba6f7" = "#8839ef";
    "#89b4fa" = "#1e66f5";
    "#94e2d5" = "#179299";
    "#b4befe" = "#7287fd";
    "#a6e3a1" = "#407a19";
    "#f9e2af" = "#8a5700";
    "#f38ba8" = "#d20f39";
    "rgba(30, 30, 46," = "rgba(239, 241, 245,";
    "rgba(49, 50, 68," = "rgba(230, 233, 239,";
  };
in
mode: text:
if mode == "light" then
  builtins.replaceStrings (builtins.attrNames latte) (builtins.attrValues latte) text
else
  text
