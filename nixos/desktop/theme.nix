{ pkgs, config, ... }:
{

  # Set theme need by Dconf
  programs.dconf.enable = true;

  # Use home-manager set theme
  # myuser.hm.gtk = {
  #   enable = true;
  #   theme = {
  #     package = pkgs.catppuccin-gtk;
  #     name = "Catppuccin-Dark";
  #   };
  #   cursorTheme = {
  #     package = pkgs.bibata-cursors;
  #     name = "Bibata-Original-Ice";
  #     size = 24;
  #   };
  #   iconTheme = {
  #     name = "Colloid";
  #     package = pkgs.colloid-icon-theme;
  #   };
  #   gtk4.theme = null;
  # };

  myuser.hm.home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Original-Ice";
    size = 24;
  };
}
