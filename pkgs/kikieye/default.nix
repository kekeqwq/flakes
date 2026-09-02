{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "kikieye";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "kikieye";
    rev = "1a80d64bf47da7444f0e55e55c64fb96bf7703a3";
    hash = "sha256-6lwquubjUmqhyCWQUKRgjnGQC0D5LwzMW0Z7p94KFSM=";
  };

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -fobjc-arc -fvisibility=hidden \
      -framework Cocoa \
      -framework AVFoundation \
      -framework CoreMedia \
      -framework CoreVideo \
      -framework QuartzCore \
      -framework AudioToolbox \
      -sectcreate __TEXT __info_plist Info.plist \
      -o kikieye kikieye.m
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app=$out/Applications/KikiEye.app
    mkdir -p $app/Contents/MacOS $app/Contents/Resources $out/bin
    install -m755 kikieye $app/Contents/MacOS/kikieye
    cp Info.plist $app/Contents/Info.plist
    printf 'APPL????' > $app/Contents/PkgInfo
    cp AppIcon.icns $app/Contents/Resources/AppIcon.icns
    cp icon.png $app/Contents/Resources/icon.png
    ln -s $app/Contents/MacOS/kikieye $out/bin/kikieye
    printf '%s\n' '#!/bin/sh' "exec /usr/bin/open -n \"$app\"" > $out/bin/kikieye-app
    chmod +x $out/bin/kikieye-app
    runHook postInstall
  '';

  meta = {
    description = "Borderless 2560×1440@120 capture-card monitor";
    homepage = "https://github.com/kekeqwq/kikieye";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "kikieye";
  };
}
