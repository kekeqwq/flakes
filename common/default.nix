_: {
  imports = [
    ./fish.nix
    ./pkgs.nix
    ./options.nix
    ./git.nix
    ./tmux.nix
    # ./zellij.nix
    ./yazi.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
