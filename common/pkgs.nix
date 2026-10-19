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
    btop
    zip
    stylua
    # XeLaTeX + packages used by resume-master/keke_cv.tex (including local moderncv).
    # Avoid broad collections: their closure exceeds macOS Seatbelt's profile limit.
    (texliveBasic.withPackages (
      ps: with ps; [
        latex-bin
        xetex
        latexmk
        fontspec
        xunicode
        xecjk
        ctex
        etoolbox
        fancyhdr
        geometry
        hyperref
        microtype
        pgf
        marvosym
        colortbl
        xcolor
        lm
        tipa
        zapfding
        greek-fontenc
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
    dua
    p7zip
    python3
    basedpyright
    fd
    unzip
    unrar
    aria2
    ripgrep
  ];
}
