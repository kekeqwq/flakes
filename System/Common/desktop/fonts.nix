{ pkgs, ... }:
{
  # Font dependencies of shared GUI programs, including WezTerm and Emacs.
  # MonoLisa files are supplied by the user and tracked with this flake.
  fonts.packages = with pkgs; [
    (callPackage ../../../pkgs/monolisa-nasy { })
    dejavu_fonts
    lxgw-wenkai
    nerd-fonts.symbols-only
    (noto-fonts.override { variants = [ "Noto Sans Symbols 2" ]; })
  ];
}
