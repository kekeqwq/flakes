_: {
  imports = [
    ../../System/Common
    ./system.nix
    ./security.nix
    ./ghostty.nix
    ./input-method.nix
    ./emacs-rime.nix
    ./rime-squirrel.nix
    ./shell.nix
    ./yazi.nix
  ];
  my.desktop.enable = true;
}
