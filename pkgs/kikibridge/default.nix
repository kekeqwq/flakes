{
  lib,
  stdenv,
  fetchFromGitHub,
  actool,
}:

stdenv.mkDerivation rec {
  pname = "kikibridge";
  version = "0.7.24";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "kikibridge-macos";
    rev = "438c427f1ed8783f5fcbd6ebd7e63c65ae17046d";
    hash = "sha256-bOL4KZla/NPyPoNOZXXLRXRrJb42TY34b4i03HVhSUU=";
  };

  nativeBuildInputs = [ actool ];
  dontUseNixBuildInputsCompiler = true;
  __noChroot = true;

  buildPhase = ''
    runHook preBuild
    unset NIX_CFLAGS_COMPILE NIX_LDFLAGS CC CXX MACOSX_DEPLOYMENT_TARGET SDKROOT
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
    triple="${if stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"}-apple-macos27.0"
    echo "kikibridge: DEVELOPER_DIR=$DEVELOPER_DIR"
    echo "kikibridge: SDK=$SDK"
    echo "kikibridge: SWIFT=$SWIFT"
    "$SWIFT" -O -parse-as-library \
      -sdk "$SDK" -target "$triple" \
      -Xfrontend -disable-sandbox \
      -o kikibridge \
      Entry.swift App.swift Bridge.swift Tap.swift \
      -framework SwiftUI -framework AppKit -framework Combine \
      -framework ApplicationServices -framework CoreGraphics \
      -framework IOKit -framework QuartzCore -framework Foundation \
      -framework Cocoa
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app=$out/Applications/KikiBridge.app
    mkdir -p $app/Contents/MacOS $app/Contents/Resources $out/bin
    cp kikibridge $app/Contents/MacOS/kikibridge
    cp Info.plist $app/Contents/Info.plist
    printf 'APPL????' > $app/Contents/PkgInfo
    cp kikibridge.png $app/Contents/Resources/kikibridge.png
    cp kikibridge-template.png $app/Contents/Resources/kikibridge-template.png
    cp karabiner-kikibridge.json $app/Contents/Resources/karabiner-kikibridge.json
    cp icon.png $app/Contents/Resources/icon.png
    cp AppIcon.icon/Assets/girl.png $app/Contents/Resources/girl.png
    cp -R AppIcon.icon $app/Contents/Resources/AppIcon.icon
    actool AppIcon.icon \
      --compile $app/Contents/Resources \
      --platform macosx \
      --minimum-deployment-target 27.0 \
      --app-icon AppIcon \
      --include-all-app-icons \
      --standalone-icon-behavior none \
      --target-device mac \
      --output-partial-info-plist $TMPDIR/assetcatalog_generated_info.plist \
      --output-format human-readable-text
    test -f $app/Contents/Resources/Assets.car
    rm -f $app/Contents/Resources/AppIcon.icns
    if command -v codesign >/dev/null 2>&1; then
      codesign --force --deep --sign - "$app" || true
    fi
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
    printf '%s\n' '#!/bin/sh' "exec /usr/bin/open -n \"$app\"" > $out/bin/kikibridge-app
    chmod +x $out/bin/kikibridge-app
    runHook postInstall
  '';

  meta = {
    description = "KikiBridge macOS sender";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "kikibridge";
  };
}
