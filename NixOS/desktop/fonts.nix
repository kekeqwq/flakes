{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "MonoLisa Nasy" ];
      monospace = [ "MonoLisa Nasy" ];
    };
    localConf = builtins.readFile ./fontconfig.xml;
  };
}
