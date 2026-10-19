self: super: {
  kikieye = super.callPackage ./kikieye { };
  kikibridge = super.callPackage ./kikibridge { };
  kikibridge-rx = super.callPackage ./kikibridge-rx { };
  kikinavmap = super.callPackage ./kikinavmap { };
  xrock = super.callPackage ./xrock { };

  # PR: https://github.com/NixOS/nixpkgs/pull/552646 (待 PR 合并后删除)
  localsend-cli = super.callPackage ./localsend-cli { };

  emacs-head = super.emacs.overrideAttrs (old: {
    pname = "emacs-head";
    version = "2026-10-19";
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      rev = "06f3da3e675c87fd85feb888c46e181faddd337e";
      hash = "sha256-tkoIDDdmdYMx1GchFZv+wNCxeACJAcHhsMigu+xZLXs=";
    };
    patches =
      builtins.filter (
        p:
        let
          name = if builtins.isAttrs p && p ? name then p.name else baseNameOf (toString p);
        in
        # These release-branch security fixes are already present in master.
        !(builtins.any (cve: super.lib.hasInfix cve name) [
          "CVE-2024-53920"
          "CVE-2026-108976"
        ])
      ) (old.patches or [ ])
      ++ super.lib.optionals super.stdenv.hostPlatform.isDarwin [
        (super.fetchpatch {
          url = "https://raw.githubusercontent.com/ryankask/homebrew-emacs-plus/d4e7cfe69322651794dfc10c09b2f6510caf6cd6/patches/emacs-32/round-undecorated-frame.patch";
          hash = "sha256-5/XyOD2ter4syVDSKnIqR2nvqeMbtXy4SKvMZqmCums=";
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
