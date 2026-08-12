{ pkgs, ... }:
let
  yazi-flavors = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "flavors";
    rev = "be0b21d0873092a63946cc2678dd700aac945902";
    hash = "sha256-Dy73TfcrcbCXY9lwDszNgAKLiCAHf1KIwC4Q5U6k21E=";
  };
in
{
  myuser.hm.programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    shellWrapperName = "y";
    theme.flavor = {
      dark = "catppuccin-macchiato";
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
      opener = {
        img = [
          {
            run = "qimgv %s";
            orphan = true;
            for = "unix";
          }
          {
            run = "localsend_app %s";
            orphan = true;
            for = "unix";
          }
        ];

        vid = [
          {
            run = "mpv %s";
            orphan = true;
            for = "unix";
          }
        ];
      };
      open.rules = [
        {
          mime = "image/*";
          use = "img";
        }
        {
          mime = "video/*";
          use = "vid";
        }
      ];
    };
  };
  myuser.hm.xdg.configFile."yazi/flavors/catppuccin-macchiato.yazi".source =
    "${yazi-flavors}/catppuccin-macchiato.yazi";
}
