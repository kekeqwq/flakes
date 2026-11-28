{
  config,
  lib,
  pkgs,
  ...
}:
let
  flavors = [
    "latte"
    "mocha"
  ];
  theme =
    variant:
    pkgs.catppuccin-gtk.override {
      inherit variant;
      accents = [ "mauve" ];
      size = "standard";
      tweaks = [ "rimless" ];
    };
  iconVariant =
    flavor:
    pkgs.catppuccin-papirus-folders.override {
      inherit flavor;
      accent = "mauve";
    };
  # Install exactly one provider for each theme name. Both full upstream
  # outputs also ship a directory called Papirus, so don't add both directly.
  icons = pkgs.linkFarm "catppuccin-papirus-light-and-dark" [
    {
      name = "share/icons/Papirus";
      path = "${iconVariant "mocha"}/share/icons/Papirus";
    }
    {
      name = "share/icons/Papirus-Dark";
      path = "${iconVariant "mocha"}/share/icons/Papirus-Dark";
    }
    {
      name = "share/icons/Papirus-Light";
      path = "${iconVariant "latte"}/share/icons/Papirus-Light";
    }
  ];
  hm = config.home-manager.users.${config.myuser.name};
  selected =
    file: hm.lib.file.mkOutOfStoreSymlink "${config.my.desktop.appearance.root}/current/${file}";
  gtk4 =
    mode:
    let
      flavor = if mode == "light" then "latte" else "mocha";
    in
    "${theme flavor}/share/themes/catppuccin-${flavor}-mauve-standard+rimless/gtk-4.0";
in
{
  programs.dconf.enable = true;
  my.desktop.appearance.files = lib.genAttrs [ "light" "dark" ] (mode: {
    "gtk4.css" = "${gtk4 mode}/gtk.css";
    "gtk4-assets" = "${gtk4 mode}/assets";
  });
  myuser.hm = {
    home.packages = map theme flavors;
    gtk = {
      enable = true;
      # Generic families deliberately resolve through Fontconfig, not a CSS
      # override. Appearance comes from the session's GSettings, not a forced
      # GTK_THEME variable or a permanently dark GTK4 stylesheet.
      font = {
        name = "sans-serif";
        size = 11;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = icons;
      };
    };
    dconf.settings."org/gnome/desktop/interface" = {
      font-name = "sans-serif 11";
      monospace-font-name = "monospace 11";
      cursor-theme = "Bibata-Modern-Ice";
    };
    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      style.name = "kvantum";
      kvantum = {
        enable = true;
        themes = map (
          variant:
          pkgs.catppuccin-kvantum.override {
            inherit variant;
            accent = "mauve";
          }
        ) flavors;
      };
    };
    # libadwaita cannot reliably re-read a user stylesheet in an open process.
    # Future GTK4 launches keep the matching Catppuccin stylesheet and assets.
    xdg.configFile = {
      "gtk-4.0/gtk.css".source = selected "gtk4.css";
      "gtk-4.0/assets".source = selected "gtk4-assets";
      "Kvantum/kvantum.kvconfig".source = lib.mkForce (selected "kvantum.kvconfig");
    };
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
  };
}
