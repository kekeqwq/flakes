{ pkgs, ... }:
let
  gtkTheme = pkgs.catppuccin-gtk.override {
    variant = "mocha";
    accents = [ "mauve" ];
    size = "standard";
    tweaks = [ "rimless" ];
  };
in
{
  programs.dconf.enable = true;
  myuser.hm = {
    gtk = {
      enable = true;
      theme = {
        name = "catppuccin-mocha-mauve-standard+rimless";
        package = gtkTheme;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.theme = null;
    };
    # Libadwaita ignores GTK3 themes; install the matching GTK4 palette explicitly.
    xdg.configFile."gtk-4.0/gtk.css".source =
      "${gtkTheme}/share/themes/catppuccin-mocha-mauve-standard+rimless/gtk-4.0/gtk.css";
    xdg.configFile."gtk-4.0/assets".source =
      "${gtkTheme}/share/themes/catppuccin-mocha-mauve-standard+rimless/gtk-4.0/assets";
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "catppuccin-mocha-mauve-standard+rimless";
      icon-theme = "Papirus-Dark";
    };
    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      style.name = "kvantum";
      kvantum = {
        enable = true;
        settings.General.theme = "catppuccin-mocha-mauve";
        themes = [
          (pkgs.catppuccin-kvantum.override {
            variant = "mocha";
            accent = "mauve";
          })
        ];
      };
    };
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
  };
}
