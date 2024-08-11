{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    font-awesome_5
    noto-fonts-emoji
    unifont
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "MonoLisa Nasy" ];
      monospace = [ "MonoLisa Nasy" ];
    };
    localConf = builtins.readFile ../../common/.config/local.xml;
  };
}
