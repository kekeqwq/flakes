_: {
  imports = [
    ./fish.nix
    ./pkgs.nix
    ./options.nix
    ./git.nix
    ./tmux.nix
    # ./zellij.nix
    ./yazi.nix
    # ./codex.nix
    ./pi.nix
    ./pi-learn.nix
    ./rime-squirrel.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
