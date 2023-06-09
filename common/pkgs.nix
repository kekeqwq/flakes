{ pkgs, inputs, ... }: {
  nix = {
    # package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  environment.systemPackages = with pkgs; [
    htop
    nixfmt
    gcc
    exa
    pass
    neofetch
    gnumake
    ranger
    dua
    fd
    unzip
    unrar
    aria2
    ripgrep
  ];
}
