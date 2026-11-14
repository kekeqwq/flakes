{ lib, ... }:
{
  # Native macOS window chrome and Liquid Glass are private integrations.
  # Keep the shared terminal palette/fonts/shell in System/Common/desktop.
  myuser.hm.programs.ghostty.settings = {
    macos-titlebar-style = "hidden";
    background-blur = "macos-glass-clear";
    background-opacity = lib.mkForce 0.8;
  };
}
