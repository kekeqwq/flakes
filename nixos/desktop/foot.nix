{
  config,
  pkgs,
  lib,
  ...
}:
{
  myuser.hm.programs.foot = {
    enable = true;
    settings = {
      main.term = "xterm-256color";
      main.font = "MonoLisa Nasy:size=11";
      colors.alpha = 0.92;
      main.initial-window-size-pixels = "1000x900";
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
}
