{ pkgs, lib, ... }:
let
  policy = import ../../System/Common/desktop/fontconfig-policy.nix { inherit lib; };
in
{
  fonts.packages = [ pkgs.noto-fonts-color-emoji ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = policy.defaultFonts // { emoji = [ "Noto Color Emoji" ]; };
    # Vendor W05 declares regular weight: correct matching, not font bytes.
    localConf = policy.rules;
  };
}
