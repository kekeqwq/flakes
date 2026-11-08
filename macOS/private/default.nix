_: {
  imports = [
    ../../System/Common
    ./system.nix
    ./input-method.nix
    ./emacs-rime.nix
    ./rime-squirrel.nix
    ./pi-learn.nix
    ./shell.nix
    ./yazi.nix
  ];
  my.desktop.enable = true;
}
