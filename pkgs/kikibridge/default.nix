{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "kikibridge";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "kikibridge-macos";
    rev = "311d46f68cb166c629bd2b4d7e4e5408878e9e83";
    hash = "sha256-8x5VuDQjhtv737nAAMFmiLTKJd6T+XNvekNiicZ5/1E=";
  };

  __darwinAllowLocalNetworking = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -fobjc-arc -fvisibility=hidden \
      -framework Cocoa \
      -framework ApplicationServices \
      -framework CoreGraphics \
      -framework Foundation \
      -framework IOKit \
      -sectcreate __TEXT __info_plist Info.plist \
      -o kikibridge kikibridge.m kikibridge-tap.m
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app=$out/Applications/KikiBridge.app
    mkdir -p $app/Contents/MacOS $app/Contents/Resources $out/bin
    cp kikibridge $app/Contents/MacOS/kikibridge
    cp Info.plist $app/Contents/Info.plist
    printf 'APPL????' > $app/Contents/PkgInfo
    cp kikibridge.icns $app/Contents/Resources/kikibridge.icns
    cp kikibridge.png $app/Contents/Resources/kikibridge.png
    cp kikibridge-template.png $app/Contents/Resources/kikibridge-template.png
    cat > $out/bin/kikibridge <<EOF
    #!/bin/sh
    set -e
    dest="\$HOME/Applications/KikiBridge.app"
    src="$app"
    mkdir -p "\$HOME/Applications"
    stamp="\$dest/Contents/Resources/.nix-out"
    if [ "\$(cat "\$stamp" 2>/dev/null || true)" != "\$src" ]; then
      rm -rf "\$dest"
      cp -R "\$src" "\$dest"
      chmod -R u+w "\$dest"
      echo "\$src" > "\$stamp"
    fi
    exec "\$dest/Contents/MacOS/kikibridge" "\$@"
    EOF
    chmod +x $out/bin/kikibridge
    runHook postInstall
  '';

  meta = {
    description = "KikiBridge macOS sender (manager + tap child)";
    homepage = "https://github.com/kekeqwq/kikibridge-macos";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "kikibridge";
  };
}
