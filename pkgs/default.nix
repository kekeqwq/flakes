self: super: {
  eca = super.callPackage ./eca { };
  xrock = super.callPackage ./xrock { };
  keke-waybar-panel = super.callPackage ./keke-waybar-panel { };
  swaylock-security-key = super.callPackage ./swaylock-security-key { };
  opensctoken-pin-never = super.callPackage ./opensctoken-pin-never { };

  # The 2.11.3 AppImage's crypto libraries need this in their FHS closure.
  snipaste = super.snipaste.override {
    appimageTools = super.appimageTools // {
      wrapType2 =
        args:
        super.appimageTools.wrapType2 (
          args // { extraPkgs = p: (args.extraPkgs or (_: [ ])) p ++ [ p.libgpg-error ]; }
        );
    };
  };

  emacs-head = super.emacs.overrideAttrs (old: {
    pname = "emacs-head";
    version = "2026-11-17";
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      rev = "0d1557ee656b121bbdb51f9852d12e93b9fb0555";
      hash = "sha256-S5Mzsad29UOzwwTj3M82qW6E85vJXyYwzBpUFKODVD0=";
    };
    # Skip release security backports, but retain the platform-specific Nix
    # toolchain paths on both Linux and Darwin for downstream .eln builds.
    patches =
      builtins.filter (p: super.lib.hasSuffix "-native-comp-driver-options-30.patch" (toString p)) (
        old.patches or [ ]
      )
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

  # Keep the same immutable head across native macOS, Linux PGTK and nox.
  emacs-head-pgtk = self.emacs-head.override { withPgtk = true; };
  emacs-head-nox = self.emacs-head.override { noGui = true; };

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
      # Latest v5_2_x maintenance/default-branch commit, not v5_3_x alpha.
      rev = "dce58732acc7aeb5425b21680b01b4379ea7bf3a";
      hash = "sha256-FnsGxSS7lYyAGXAELqDnqPx4+dU4BO00OGsRwokIBrk=";
    };
  });

  NetworkManager-l2tp = (super.NetworkManager-l2tp.overrideAttrs (old: { })).override {
    withGnome = false;
  };
}
