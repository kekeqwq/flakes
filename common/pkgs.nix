{
  config,
  pkgs,
  inputs,
  ...
}:
{
  nix = {
    # package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    registry.nixpkgs.flake = inputs.nixpkgs;
    settings.trusted-users = [
      "root"
      "${config.myuser.name}"
    ];
  };

  environment.systemPackages = with pkgs; [
    nixfmt-rfc-style
    gh
    file
    htop
    gcc
    eza
    pass
    fastfetch
    gnumake
    ranger
    dua
    p7zip
    python3
    fd
    unzip
    unrar
    aria2
    ripgrep
  ];
}
