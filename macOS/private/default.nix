_: {
  imports = [
    ../../System/Common
    ./system.nix
    ./tailscale-routes.nix
    ./security.nix
    ./fonts.nix
    ./ghostty.nix
    ./input-method.nix
    ./emacs-rime.nix
    ./emacs-client.nix
    ./rime-squirrel.nix
    ./shell.nix
    ./opensctoken.nix
    ./yazi.nix
  ];
  my.desktop.enable = true;
  my.opensctoken.enable = true;
}
