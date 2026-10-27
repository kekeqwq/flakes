{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Downloads' local tools.node imports execjs; PyExecJS is not in this nixpkgs.
  # Pin and build the upstream release instead of installing into system Python.
  pyexecjs = pkgs.python3Packages.buildPythonPackage rec {
    pname = "PyExecJS";
    version = "1.5.1";
    pyproject = true;
    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-NMwdBwl2kYGD/3vcCtcfgVeokcknCMAMX7v/enafUFw=";
    };
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = [ pkgs.python3Packages.six ];
    nativeCheckInputs = [ pkgs.nodejs ];
    checkPhase = ''
      runHook preCheck
      ${pkgs.python3.interpreter} -m unittest -v test_execjs.DefaultRuntimeTest test_execjs.NodeRuntimeTest
      runHook postCheck
    '';
    pythonImportsCheck = [ "execjs" ];
  };
in
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
    nodejs # JavaScript runtime for PyExecJS.
    (python3.withPackages (
      ps: with ps; [
        curl-cffi
        beautifulsoup4
        openpyxl
        loguru
        requests
        pymongo
        redis
        pyexecjs
      ]
    ))
    basedpyright
    fd
    unzip
    unrar
    aria2
    ripgrep
  ];
}
