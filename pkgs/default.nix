self: super: {
  kikieye = super.callPackage ./kikieye { };
  kikibridge = super.callPackage ./kikibridge { };
  kikibridge-rx = super.callPackage ./kikibridge-rx { };
  kikinavmap = super.callPackage ./kikinavmap { };
  xrock = super.callPackage ./xrock { };

  emacs-head = super.emacs.overrideAttrs (old: {
    pname = "emacs-head";
    version = "2026-09-16";
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      rev = "5c91443e85c727b56dea38a0b1f7344a5cd7029e";
      hash = "sha256-bfZbf9hHgBymnX/a92OTQYcaTLEI06H55a7DG4tVUWY=";
    };
    patches =
      builtins.filter (
        p:
        let
          name = if builtins.isAttrs p && p ? name then p.name else baseNameOf (toString p);
        in
        !(super.lib.hasInfix "CVE-2024-53920" name)
      ) (old.patches or [ ])
      ++ super.lib.optionals super.stdenv.hostPlatform.isDarwin [
        (super.fetchpatch {
          url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/b7b77a8978cdfa9bbb67a8b93830813dab308a27/patches/emacs-31/round-undecorated-frame.patch";
          hash = "sha256-KCMEvJzN1OkwFYoMLpZghvdeoO1Ckcxk3Mo19YAf850=";
        })
        (super.fetchpatch {
          url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/b7b77a8978cdfa9bbb67a8b93830813dab308a27/patches/emacs-31/system-appearance.patch";
          hash = "sha256-4+2U+4+2tpuaThNJfZOjy1JPnneGcsoge9r+WpgNDko=";
        })
      ];
    postPatch =
      (old.postPatch or "")
      + super.lib.optionalString super.stdenv.hostPlatform.isDarwin ''
        substituteInPlace lisp/gnus/smime.el \
          --replace-fail '(car (gnutls-trustfiles))' '"/etc/ssl/cert.pem"'
      '';
  });

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
