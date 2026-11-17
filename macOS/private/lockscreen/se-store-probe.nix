# Owner-consented storage-only SE test. NOT imported into system activation.
{ pkgs }:
let
  identifier = "com.keke.flakes.se-store-probe";
  info = pkgs.writeText "se-store-info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>${identifier}</string>
      <key>CFBundleExecutable</key><string>se-store-probe</string>
      <key>CFBundleName</key><string>FlakesSEStoreProbe</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleVersion</key><string>1</string>
      <key>LSUIElement</key><true/>
    </dict></plist>
  '';
  entitlements = pkgs.writeText "se-store-entitlements.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>com.apple.security.app-sandbox</key><true/>
      <key>com.apple.security.smartcard</key><true/>
    </dict></plist>
  '';
in
pkgs.runCommand "flakes-se-store-probe"
  {
    nativeBuildInputs = [
      pkgs.stdenv.cc
      pkgs.darwin.cctools
    ];
  }
  ''
    app="$out/FlakesSEStoreProbe.app"
    mkdir -p "$app/Contents/MacOS" "$out/bin"
    cp ${info} "$app/Contents/Info.plist"
    cc -Wall -Wextra -Werror -fobjc-arc -I${./.} ${./se-store-probe.m} \
      -framework Foundation -framework Security -framework LocalAuthentication \
      -framework CoreGraphics -framework IOKit -o "$app/Contents/MacOS/se-store-probe"
    /usr/bin/codesign --force --sign - --timestamp=none --identifier ${identifier} \
      --entitlements ${entitlements} "$app"
    /usr/bin/codesign --verify --strict "$app"
    cc -Wall -Wextra -Werror -fobjc-arc -I${./.} ${../../../tests/macos-lock-gate.m} \
      -framework Foundation -framework CoreGraphics -framework IOKit -o gate-test
    ./gate-test
    printf '%s\n' '#!${pkgs.runtimeShell}' 'set -euo pipefail' \
      "exec ${pkgs.python3}/bin/python3 ${../../../tests/macos-se-store.py} \"$app\" \"\$@\"" \
      > "$out/bin/flakes-test-se-store"
    chmod 755 "$out/bin/flakes-test-se-store"
  ''
