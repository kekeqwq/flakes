{ pkgs, ... }:
let
  yazi-flavors = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "flavors";
    rev = "1183892c904f7f0efdf4473e856ed308b7bea98d";
    hash = "sha256-E1OUF1+mT0V3crVxkewG2Y7hRu8fO+0oRl6NlINmw+o=";
  };
in
{
  myuser.hm.programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    shellWrapperName = "y";
    theme.flavor = {
      dark = "catppuccin-mocha";
      light = "catppuccin-latte";
    };
    settings = {
      mgr = {
        show_hidden = true;
        ratio = [
          0
          1
          4
        ];
      };
      preview = {
        max_width = 3840;
        max_height = 2160;
        image_delay = 0;
        image_filter = "lanczos3";
        image_quality = 90;
      };
    };
  };
  myuser.hm.xdg.configFile = {
    "yazi/flavors/catppuccin-mocha.yazi".source = "${yazi-flavors}/catppuccin-mocha.yazi";
    "yazi/flavors/catppuccin-latte.yazi".source = "${yazi-flavors}/catppuccin-latte.yazi";
  };
}
