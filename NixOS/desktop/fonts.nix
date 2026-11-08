{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji
    nerd-fonts.symbols-only
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
