self: super: {
  kikieye = super.callPackage ./kikieye { };
  kikibridge = super.callPackage ./kikibridge { };
  kikibridge-rx = super.callPackage ./kikibridge-rx { };
  xrock = super.callPackage ./xrock { };

  weylus-community = super.weylus.overrideAttrs (o: {
    version = "fd1f1f1";
    pname = "weylus-community";
    src = super.fetchFromGitHub {
      repo = "WeylusCommunityEdition";
      owner = "electronstudio";
      rev = "fd1f1f1efc910613d8a80d7e73d24b667a6d8b4a";
      sha256 = "sha256-Q3gipRgZCzihKUQZZmETT65AUSEUfgj9dFxZFybq258=";
    };
  });

  qbittorrent = super.qbittorrent.overrideAttrs (o: {
    version = "5.12.1.10";
    pname = "qbittorrent-enhamced";
    src = super.fetchFromGitHub {
      repo = "qBittorrent-Enhanced-Edition";
      owner = "c0re100";
      rev = "4f3a99a526f461fe49d8dc29f164600eb239eeb6";
      sha256 = "sha256-Q3gipRgZCzihKUQZZmETT65AUSEUfgj9dFxZFybq258=";
    };
  });

  NetworkManager-l2tp = (super.NetworkManager-l2tp.overrideAttrs (old: { })).override {
    withGnome = false;
  };
}
