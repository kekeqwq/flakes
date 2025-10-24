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
      colors = {
        alpha = 0.92;
        # foreground = "D8DEE9";
        # background = "2E3440";
        # regular0 = "3B4252";
        # bright0 = "4C566A";
        # regular1 = "BF616A";
        # bright1 = "BF616A";
        # regular2 = "A3BE8C";
        # bright2 = "A3BE8C";
        # regular3 = "EBCB8B";
        # bright3 = "EBCB8B";
        # regular4 = "81A1C1";
        # bright4 = "81A1C1";
        # regular5 = "B48EAD";
        # bright5 = "B48EAD";
        # regular6 = "88C0D0";
        # bright6 = "88C0D0";
        # regular7 = "E5E9F0";
        # bright7 = "ECEFF4";
      };
      main.initial-window-size-pixels = "1000x900";
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
}
