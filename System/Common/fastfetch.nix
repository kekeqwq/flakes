_: {
  # The executable is supplied by Common/pkgs.nix. Keep its configuration and
  # ASCII resource together so fresh Linux/macOS homes get the same display.
  myuser.hm.xdg.configFile = {
    "fastfetch/config.jsonc" = {
      source = ./fastfetch/config.jsonc;
      force = true;
    };
    "fastfetch/ascii.txt" = {
      source = ./fastfetch/ascii.txt;
      force = true;
    };
  };
}
