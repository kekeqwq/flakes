_: {
  imports = [
    ./pkgs.nix
    ./options.nix
    ./zsh.nix
    ./homefile.nix
    ./git.nix
    ./tmux.nix
    ./configuration.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
