{ pkgs, ... }: {

  # Set theme need by Dconf
  programs.dconf.enable = true;

  # Use home-manager set theme
  myuser.hm.gtk = {
    enable = true;
    theme = {
      name = "Orchis-Green-Dark";
      package = pkgs.orchis-theme;
    };
    iconTheme = {
      name = "Fluent";
      package = pkgs.fluent-icon-theme;
    };
  };
  myuser.hm.qt = {
    enable = true;
    platformTheme.name = "gtk";
  };

  myuser.hm.home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
  };
}
