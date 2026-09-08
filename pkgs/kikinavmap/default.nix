{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "kikinavmap";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "KikiNavMap";
    rev = "2259f0cc9237408e96660d565b1694c890a21eae";
    hash = "sha256-xwqIapVu9VtNHRmslBkhqB0xQr/y/JY/6D1sucXBiJ0=";
  };

  dontUseNixBuildInputsCompiler = true;
  __noChroot = true;

  buildPhase = ''
    runHook preBuild
    unset NIX_CFLAGS_COMPILE NIX_LDFLAGS CC CXX MACOSX_DEPLOYMENT_TARGET SDKROOT DEVELOPER_DIR
    if [ -d /Applications/Xcode-beta.app/Contents/Developer ]; then
      export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
      export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    else
      export DEVELOPER_DIR=$(/usr/bin/xcode-select -p)
    fi
    SDK=$(/usr/bin/xcrun --sdk macosx --show-sdk-path)
    SWIFT=$(/usr/bin/xcrun -f swiftc)
    test -n "$SDK" -a -x "$SWIFT"
    triple="${if stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}-apple-macos14.0"
    echo "kikinavmap: DEVELOPER_DIR=$DEVELOPER_DIR"
    echo "kikinavmap: SDK=$SDK"
    echo "kikinavmap: SWIFT=$SWIFT"

    PLUGIN_DIR="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
    EXTRA_FLAGS=""
    if [ -d "$PLUGIN_DIR" ]; then
      EXTRA_FLAGS="-plugin-path $PLUGIN_DIR"
    fi

    mkdir -p .build/cache
    "$SWIFT" -O -parse-as-library \
      -sdk "$SDK" -target "$triple" \
      -Xfrontend -disable-sandbox \
      -module-cache-path .build/cache \
      $EXTRA_FLAGS \
      -o kikinavmap \
      $(find Sources/KikiNavMap -name "*.swift") \
      -framework SwiftUI -framework AppKit -framework MapKit \
      -framework CoreLocation -framework Combine -framework Foundation \
      -framework Cocoa
    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        app=$out/Applications/KikiNavMap.app
        mkdir -p $app/Contents/MacOS $app/Contents/Resources $out/bin
        cp kikinavmap $app/Contents/MacOS/kikinavmap
        cp Info.plist $app/Contents/Info.plist
        printf 'APPL????' > $app/Contents/PkgInfo
        if [ -d Sources/KikiNavMap/Resources ]; then
          cp -R Sources/KikiNavMap/Resources/* $app/Contents/Resources/ || true
        fi
        if command -v codesign >/dev/null 2>&1; then
          codesign --force --deep --sign - "$app" || true
        fi
        cat > $out/bin/kikinavmap <<EOF
    #!/bin/sh
    set -e
    dest="\$HOME/Applications/KikiNavMap.app"
    src="$app"
    mkdir -p "\$HOME/Applications"
    stamp="\$dest/Contents/Resources/.nix-out"
    if [ "\$(cat "\$stamp" 2>/dev/null || true)" != "\$src" ]; then
      rm -rf "\$dest"
      cp -R "\$src" "\$dest"
      chmod -R u+w "\$dest"
      echo "\$src" > "\$stamp"
    fi
    exec "\$dest/Contents/MacOS/kikinavmap" "\$@"
    EOF
        chmod +x $out/bin/kikinavmap
        printf '%s\n' '#!/bin/sh' "exec /usr/bin/open -n \"$app\"" > $out/bin/kikinavmap-app
        chmod +x $out/bin/kikinavmap-app
        runHook postInstall
  '';

  meta = {
    description = "KikiNavMap — Flight Plan Navigation Mapper with Liquid Glass UI";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "kikinavmap";
  };
}
