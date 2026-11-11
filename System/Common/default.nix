_: {
  imports = [
    ./fish.nix
    ./fastfetch.nix
    ./pkgs.nix
    ./options.nix
    ./git.nix
    ./tmux.nix
    ./yazi.nix
    # ./codex.nix
    ./pi.nix
    ./emacs.nix
    ./desktop
  ];
  myuser.name = "keke";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
