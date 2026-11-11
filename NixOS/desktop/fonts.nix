{ pkgs, ... }:
{
  fonts.packages = [ pkgs.noto-fonts-color-emoji ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      # MonoLisa supplies Latin; LXGW supplies simplified/traditional Chinese.
      sansSerif = [
        "MonoLisa Nasy"
        "LXGW WenKai"
      ];
      serif = [
        "MonoLisa Nasy"
        "LXGW WenKai"
      ];
      monospace = [
        "MonoLisa Nasy"
        "LXGW WenKai Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
