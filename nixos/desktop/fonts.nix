{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts-emoji
    nerd-fonts.symbols-only
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
