_: {
  imports = [
    ./pkgs.nix
    ./options.nix
    ./git.nix
    ./tmux.nix
    ./configuration.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
