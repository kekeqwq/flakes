{ pkgs, ... }:
let
  # Only the C module is exported. Elpaca manages the Lisp frontend.
  native = pkgs.runCommand "emacs-rime-native" { } ''
    mkdir -p "$out"
    cp ${pkgs.emacsPackages.rime}/share/emacs/site-lisp/elpa/rime-*/librime-emacs${pkgs.stdenv.hostPlatform.extensions.sharedLibrary} "$out/"
  '';
in
{
  myuser.hm.home.file.".local/share/emacs-rime-native".source = native;
}
