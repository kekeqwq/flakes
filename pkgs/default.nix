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

  # Official Enhanced release, built without the Qt GUI. Do not override the
  # generic qbittorrent package or keep a second development-branch source.
  qbittorrent-enhanced-nox = super.qbittorrent-enhanced-nox.overrideAttrs (_: {
    version = "5.2.4.10";
    src = super.fetchFromGitHub {
      owner = "c0re100";
      repo = "qBittorrent-Enhanced-Edition";
      # release-5.2.4.10, resolved to an immutable commit.
      rev = "ec66016a20d4dc7ba0f5bf4587b9d0577f2f886c";
      hash = "sha256-3eGwURv0kGcuAzUUTaMkplXXgKgi1C/0qcutt3l8mxA=";
    };
  });

  NetworkManager-l2tp = (super.NetworkManager-l2tp.overrideAttrs (old: { })).override {
    withGnome = false;
  };
}
