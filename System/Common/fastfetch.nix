{ pkgs, ... }:
let
  logo = if pkgs.stdenv.hostPlatform.isDarwin then ./fastfetch/apple.txt else ./fastfetch/nixos.txt;
in
{
  # The executable is supplied by Common/pkgs.nix. Each system gets its own
  # large logo; the small OS icon is selected by fastfetch itself.
  myuser.hm.xdg.configFile = {
    "fastfetch/config.jsonc" = {
      source = ./fastfetch/config.jsonc;
      force = true;
    };
    "fastfetch/ascii.txt" = {
      source = logo;
      force = true;
    };
  };
}
