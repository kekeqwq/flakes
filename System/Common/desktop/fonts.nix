{ pkgs, ... }:
{
  # Font dependencies of shared GUI programs, including Ghostty and Emacs.
  # MonoLisa files are supplied by the user and tracked with this flake.
  fonts.packages = with pkgs; [
    (callPackage ../../../pkgs/monolisa-nasy { })
    dejavu_fonts
    (callPackage ../../../pkgs/tsanger-jinkai { })
    nerd-fonts.symbols-only
    (noto-fonts.override { variants = [ "Noto Sans Symbols 2" ]; })
  ];
}
