{ pkgs, ... }:
{
  # Font dependencies of shared GUI programs, including WezTerm and Emacs.
  # MonoLisa Nasy remains an optional privately installed font.
  fonts.packages = with pkgs; [
    dejavu_fonts
    lxgw-wenkai
    nerd-fonts.symbols-only
    (noto-fonts.override { variants = [ "Noto Sans Symbols 2" ]; })
  ];
}
