{ pkgs, ... }:
{
  services.udev.packages = with pkgs; [
    via
    android-udev-rules
  ];
  hardware.opentabletdriver.enable = true;
  virtualisation.podman.enable = true;
  programs.adb.enable = true;
  myuser.users = {
    extraGroups = [ "adbusers" ];
  };
  #allow touch lite
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="109b", ATTR{idProduct}=="911f", MODE="0666", GROUP="adbusers"
  '';

  # WORKAROUND: I don't build firefox.
  # myuser.hm.programs.firefox.package = pkgs.firefox-bin;

  # security.pam.services.swaylock = { };
  # nix-flake-utils-plus force use nix unstable
  # nix.package = pkgs.nix;
  programs.steam.enable = true;
  # Application
  environment.systemPackages = with pkgs; [
    distrobox
    via
    # anki-bin
    xournalpp
    jmtpfs
    chromium
    goldendict-ng
    gimp
    remmina
    # Study
    # zotero
    # mask for https://github.com/NixOS/nixpkgs/pull/201028
    # goldendict

    # Language
    ## Clojure
    # clojure
    # leiningen
    # clojure-lsp
    # jdk17

    ## Golang
    # go
    # gopls

    ## Nix
    #rnix-lsp

    ## C

    ## Python
    # python310
    # pyright

    ## Rust
    rustc
    rustfmt
    cargo
    rust-analyzer
    # libiconv

    ## Haskell
    # ghc
    # cabal-install
    # haskell-language-server
    # stack

    ## Tex
    # texlab
    # (texlive.combine {
    #   inherit (texlive)
    #     scheme-basic collection-bibtexextra collection-binextra
    #     collection-fontutils collection-formatsextra collection-humanities
    #     collection-langchinese collection-langcjk collection-langenglish
    #     collection-latexextra collection-latexrecommended collection-mathscience
    #     collection-plaingeneric collection-pstricks collection-xetex;
    # })

    # Base
    # qq
    sioyek
    # clash
    logseq
    qbittorrent
    # xmobar
    # trayer
    # xkeysnail
    # zathura
    # xsettingsd
    # dunst
    # (pkgs.dwarf-fortress-packages.dwarf-fortress-full.override {
    #   theme = "phoebus";
    #   enableIntro = false;
    #   enableFPS = true;
    # })
  ];
  # Require steam
  # hardware.pulseaudio.support32Bit = true;
  # hardware.opengl = {
  #   driSupport = true;
  #   driSupport32Bit = true;
  # };

}
