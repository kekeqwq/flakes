_: {
  imports = [
    ./fish.nix
    ./zoxide.nix
    ./tailscale.nix
    ./fastfetch.nix
    ./pkgs.nix
    ./options.nix
    ./git.nix
    ./tmux.nix
    ./yazi.nix
    ./pi.nix
    ./emacs.nix
    ./desktop
  ];
  myuser.name = "keke";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
