{ lib, pkgs, ... }:
{
  # Shared desktop Emacs. ghostel (libghostty terminal) comes from nixpkgs'
  # own derivation on every platform: it builds its Zig module from a
  # fixed-output dependency set and needs no per-platform patching. Darwin
  # used to carry a melpa2nix-based override that nixpkgs no longer matches.
  myuser.hm.programs.emacs = {
    package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-head else pkgs.emacs-pgtk;
    extraPackages = epkgs: [ epkgs.ghostel ];
  };
}
