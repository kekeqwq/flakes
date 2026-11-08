{ lib, pkgs, ... }:
{
  # Headless systems get terminal Emacs. The shared desktop layer selects the
  # graphical backend without duplicating the editor's configuration per OS.
  myuser.hm.programs.emacs = {
    enable = true;
    package = lib.mkDefault pkgs.emacs-nox;
  };
}
