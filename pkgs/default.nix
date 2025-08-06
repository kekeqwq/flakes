let
  # Cataclysm-DDA-git
  cdda_version = "cdda-experimental-2023-04-15";
  cdda_rev = "b4113c1caffa239d4a71cf3c32d4f099025af36a";
  cdda_sha256 = "sha256-v914LxSAEsIWziVVJCIHetHRhYzAmMPrrkxC2mR37Zk=";
  # Brave
  brave_version = "1.44.105";
  brave_sha256 = "sha256-m4wmUc5EcJ+hKG/yCcbpfYPvBCeX4InVNF4OdjLYsTc=";
  # Emacs
  # emacs_rev = "112858c40f52411932f79cf997795c54d54717c6";
  # emacs_sha256 = "sha256-60NHLkNyBbrtliTpd3Is7K7Gd0cpYEgra4tfCU0ntIU=";
  # Edge
  edge_version = "114.0.1788.0-1";
  edge_sha256 = "sha256-ydqRbeeIsWTXS24n0/5sRC7Z5qkLJ2TQo7qRfWTE0Kc=";
in
self: super: {
  # My Packages ---------------------------------------------------------------

  yabai-bin = super.callPackage ./yabai-bin { };

  style-detector = super.callPackage ./style-detector { };

  anki-bin = super.anki-bin.overrideAttrs (o: {
    version = "23.10b6";
    sources = super.fetchurl {
      url = "https://github.com/ankitects/anki/releases/download/23.10beta6/anki-23.10-linux-qt6.tar.zst";
      sha256 = "sha256-IRW2hicZ2a5oM7OSnEeZJV30joI/s5oclgqkRXb34ig=";
    };
  });

  # kitty = super.kitty.overrideAttrs (o: rec {
  #   patches = o.patches ++ super.lib.optionals super.stdenv.isDarwin
  #     [ ../files/fix-stack_size.patch ];
  # });

  #temp fix
  aria2 = super.aria2.overrideAttrs (o: rec {
    patches = [ ];
  });

  # meson Workaround
  # https://github.com/NixOS/nixpkgs/issues/229358
  # Wait: https://nixpk.gs/pr-tracker.html?pr=229528
  # meson = super.meson.overrideAttrs (o: {
  #   patches = o.patches ++ [
  #     (super.fetchpatch {
  #       url =
  #         "https://github.com/mesonbuild/meson/commit/7c78c2b5a0314078bdabb998ead56925dc8b0fc0.patch";
  #       sha256 = "sha256-vSnHhuOIXf/1X+bUkUmGND5b30ES0O8EDArwb4p2/w4=";
  #     })
  #   ];
  # });

  # My waybar
  # waybar = super.waybar.overrideAttrs
  #   (o: { mesonFlags = o.mesonFlags ++ [ "-Dexperimental=true" ]; });

  # My DWM ---------------------------------------------------------------

  dwm = super.dwm.overrideAttrs (o: {
    version = "2022-12-11";
    src = super.fetchFromGitLab {
      repo = "dwm";
      owner = "haveagoodtime";
      rev = "903a98a76ceefb4f1cff77ecb034802e7a3009c9";
      sha256 = "sha256-AuS14oPF6EL3yZxfNsTJ2o0V/gJpMyGOZcliIzrL4is=";
    };
  });

  # My shattered-pixel-dungeon
  # shattered-pixel-dungeon = super.shattered-pixel-dungeon.overrideAttrs (o: {
  #   version = "1.3.2";
  #   src = super.fetchFromGitHub {
  #     repo = "shattered-pixel-dungeon";
  #     owner = "00-Evan";
  #     rev = "4f32d906a05a3b56a60d34d6e835a53c50280a01";
  #     sha256 = "sha256-siHKdeuEZmaCf064FL6xS8qRhbB9/F6h0RVw+dsDKLE=";
  #   };
  # });

  # My Logseq
  # logseq = super.logseq.overrideAttrs (o: {
  #   version = "0.8.5";
  #   src = super.fetchurl {
  #     url =
  #       "https://github.com/logseq/logseq/releases/download/0.8.5/Logseq-linux-x64-0.8.5.AppImage";
  #     sha256 = "sha256-1nvkjucMRAwpqg2LI+1UrICMLzSd6t0yGnYdCUNQslU=";
  #   };
  # });

  # My Brave
  brave = super.brave.overrideAttrs (o: {
    version = "${brave_version}";
    src = super.fetchurl {
      url = "https://github.com/brave/brave-browser/releases/download/v${brave_version}/brave-browser_${brave_version}_amd64.deb";
      sha256 = "${brave_sha256}";
    };
  });

  # My Edge
  microsoft-edge-dev = super.microsoft-edge-dev.overrideAttrs (o: {
    version = "${edge_version}";
    src = super.fetchurl {
      url = "https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-dev/microsoft-edge-dev_${edge_version}_amd64.deb";
      sha256 = "${edge_sha256}";
    };
  });

  # My qbittorrent
  qbittorrent = super.qbittorrent.overrideAttrs (o: {
    version = "4.6.1.10";
    pname = "qbittorrent-enhamced";
    src = super.fetchFromGitHub {
      repo = "qBittorrent-Enhanced-Edition";
      owner = "c0re100";
      rev = "294ddf94a769bca822e9698cfd23ab6247cdb2d7";
      sha256 = "sha256-flcvWFWGNcUhgpI5YCKIgJrCbp2Q6cE2WaaluYVNKoA=";
    };
  });

  # Master Version CDDA
  cataclysm-dda-git = super.cataclysm-dda-git.overrideAttrs (o: {
    version = "${cdda_version}";
    makeFlags = o.makeFlags ++ [ "VERSION=${cdda_version}" ];
    src = super.fetchFromGitHub {
      repo = "Cataclysm-DDA";
      owner = "CleverRaven";
      rev = "${cdda_rev}";
      sha256 = "${cdda_sha256}";
    };
    patches = [ ./00-patchs/cataclysmdda-fix-lang.patch ];
  });

  # My Picom ---------------------------------------------------------------

  picom = super.picom.overrideAttrs (o: {
    src = super.fetchFromGitHub {
      repo = "picom";
      owner = "dccsillag";
      rev = "51b21355696add83f39ccdb8dd82ff5009ba0ae5";
      sha256 = "sha256-crCwRJd859DCIC0pEerpDqdX2j8ZrNAzVaSSB3mTPN8=";
    };
    # src = super.fetchFromGitHub {
    #   repo = "picom";
    #   owner = "jonaburg";
    #   rev = "e3c19cd7d1108d114552267f302548c113278d45";
    #   sha256 = "sha256-4voCAYd0fzJHQjJo4x3RoWz5l3JJbRvgIXn1Kg6nz6Y=";
    # };
    # src = super.fetchFromGitHub {
    #   repo = "picom";
    #   owner = "ibhagwan";
    #   rev = "c4107bb6cc17773fdc6c48bb2e475ef957513c7a";
    #   sha256 = "sha256-1hVFBGo4Ieke2T9PqMur1w4D0bz/L3FAvfujY9Zergw=";
    # };
    # src = super.fetchFromGitHub {
    #   repo = "picom-jonaburg-fix";
    #   owner = "Arian8j2";
    #   rev = "31d25da22b44f37cbb9be49fe5c239ef8d00df12";
    #   sha256 = "sha256-1z4bKDoNgmG40y2DKTSSh1NCafrE1rkHkCB3ob8ibm4=";
    # };
  });

  # My Xmonad ---------------------------------------------------------------

  # haskellPackages = super.haskellPackages.override {
  #   overrides = hself: hsuper: {
  #     xmonad = hsuper.xmonad_0_18_0;
  #     xmonad-contrib = hsuper.xmonad-contrib_0_18_0;
  #     xmonad-extras = hsuper.xmonad-extras_0_18_0;
  #   };
  # };

  # Emacs Master And Patches ---------------------------------------------------------------

  # emacs-head = (super.emacs.overrideAttrs (old: {
  #   version = "${emacs_rev}";
  #   src = super.fetchFromGitHub {
  #     owner = "emacs-mirror";
  #     repo = "emacs";
  #     rev = "${emacs_rev}";
  #     sha256 = "${emacs_sha256}";
  #   };
  #   patches = [
  #     ./00-patchs/emacs-system-appearance.patch
  #     ./00-patchs/emacs-fix-window-role.patch
  #     ./00-patchs/emacs-round-undecorated-frame.patch
  #   ];
  #   # configureFlags = old.configureFlags ++ [ "--with-json" ];
  #   preConfigure = "./autogen.sh";
  #   buildInputs = old.buildInputs
  #     ++ [ super.autoconf super.texinfo super.tree-sitter ];
  # })).override {
  #   # withXinput2 = true;
  #   # withXwidgets = true;
  #   nativeComp = false;
  #   withGTK3 = true;
  #   withPgtk = true;
  # };
  NetworkManager-l2tp = (super.NetworkManager-l2tp.overrideAttrs (old: { })).override {
    withGnome = false;
  };

}
