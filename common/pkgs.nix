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
    (texliveSmall.withPackages (
      ps: with ps; [
        scheme-basic
        collection-bibtexextra
        collection-binextra
        collection-fontutils
        collection-formatsextra
        collection-humanities
        collection-langchinese
        collection-langcjk
        collection-langenglish
        collection-latexextra
        collection-latexrecommended
        collection-mathscience
        collection-plaingeneric
        collection-pstricks
        collection-xetex
      ]
    ))
    android-tools
    gh
    file
    htop
    gcc
    eza
    pass
    fastfetch
    gnumake
    yazi
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
