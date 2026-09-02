{
  lib,
  stdenv,
  fetchFromGitHub,
  actool,
}:

assert lib.assertMsg stdenv.hostPlatform.isDarwin "kikieye is Darwin-only";

let
  triple =
    if stdenv.hostPlatform.isAarch64 then "arm64-apple-macos27.0" else "x86_64-apple-macos27.0";
in
stdenv.mkDerivation {
  pname = "kikieye";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "kikieye";
    rev = "19622e8c1c968477a7db3f7d672fef7c003437f3";
    hash = "sha256-rZw/HQ/NUsxTTtTRJnA0urX1SKX6I5ZvOw4RkLTfDQE=";
  };

  nativeBuildInputs = [ actool ];
  dontUseNixBuildInputsCompiler = true;

  # 仅此包出沙箱，摸本机 Xcode 27。全局保持 sandbox = "relaxed"。
  __noChroot = true;

  buildPhase = ''
    runHook preBuild
    unset NIX_CFLAGS_COMPILE NIX_LDFLAGS CC CXX MACOSX_DEPLOYMENT_TARGET
    unset SDKROOT
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
    echo "kikieye: DEVELOPER_DIR=$DEVELOPER_DIR"
    echo "kikieye: SDK=$SDK"
    echo "kikieye: SWIFT=$SWIFT"
    "$SWIFT" -O -parse-as-library \
      -sdk "$SDK" -target ${triple} \
      -Xfrontend -disable-sandbox \
      -o kikieye \
      Entry.swift Config.swift App.swift Capture.swift \
      -framework SwiftUI -framework AppKit -framework AVFoundation \
      -framework CoreMedia -framework CoreVideo -framework QuartzCore \
      -framework AudioToolbox -framework Combine -framework Foundation \
      -framework Cocoa
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app=$out/Applications/KikiEye.app
    mkdir -p $app/Contents/MacOS $app/Contents/Resources $out/bin
    cp kikieye $app/Contents/MacOS/kikieye
    cp Info.plist $app/Contents/Info.plist
    printf 'APPL????' > $app/Contents/PkgInfo
    cp icon.png $app/Contents/Resources/icon.png
    cp -R AppIcon.icon $app/Contents/Resources/AppIcon.icon
    cp AppIcon.icon/Assets/eye.png $app/Contents/Resources/eye.png
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
    cat > $out/bin/kikieye <<EOF
    #!/bin/sh
    set -e
    dest="\$HOME/Applications/KikiEye.app"
    src="$app"
    mkdir -p "\$HOME/Applications"
    stamp="\$dest/Contents/Resources/.nix-out"
    if [ "\$(cat "\$stamp" 2>/dev/null || true)" != "\$src" ]; then
      rm -rf "\$dest"
      cp -R "\$src" "\$dest"
      chmod -R u+w "\$dest"
      echo "\$src" > "\$stamp"
    fi
    exec "\$dest/Contents/MacOS/kikieye" "\$@"
    EOF
    chmod +x $out/bin/kikieye
    printf '%s\n' '#!/bin/sh' "exec /usr/bin/open -n \"$app\"" > $out/bin/kikieye-app
    chmod +x $out/bin/kikieye-app
    runHook postInstall
  '';

  meta = {
    description = "KikiEye — borderless capture-card monitor";
    homepage = "https://github.com/kekeqwq/kikieye";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "kikieye";
  };
}
