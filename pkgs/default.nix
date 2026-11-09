self: super: {
  xrock = super.callPackage ./xrock { };

  emacs-head = super.emacs.overrideAttrs (old: {
    pname = "emacs-head";
    version = "2026-11-08";
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      rev = "4e520d63f9d6e148f0c3fd5d5e2448dd9c4334f2";
      hash = "sha256-n/auZ0sexvPCoU1dhtn4Zsb9O2lraLyIYfHVLr19xE8=";
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
    version = "5.2.4.10-unstable-2026-10-10";
    pname = "qbittorrent-enhanced";
    src = super.fetchFromGitHub {
      repo = "qBittorrent-Enhanced-Edition";
      owner = "c0re100";
      # Upstream's active default branch is v5_2_x, not the abandoned master.
      rev = "e883083b1154cfbb9022bdee66b119518eef6b4e";
      hash = "sha256-Hx4VNxP0D3LMtkaHspGbcGlusqVwT0ze/zOizxv9HxI=";
    };
  });

  NetworkManager-l2tp = (super.NetworkManager-l2tp.overrideAttrs (old: { })).override {
    withGnome = false;
  };
}
