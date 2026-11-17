# Experimental, credentialless metadata probe. Never part of system activation.
{ pkgs }:
let
  hostID = "com.keke.flakes.ctk-empty-probe";
  driverID = "${hostID}.driver";
  plist =
    name: attrs:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.python3 ]; } ''
      python3 - ${pkgs.writeText "${name}.json" (builtins.toJSON attrs)} "$out" <<'PY'
      import json, plistlib, sys
      with open(sys.argv[1]) as f: data = json.load(f)
      with open(sys.argv[2], 'wb') as f: plistlib.dump(data, f)
      PY
    '';
  common = {
    CFBundleInfoDictionaryVersion = "6.0";
    CFBundleVersion = "1";
    CFBundleShortVersionString = "0.0.1";
    LSMinimumSystemVersion = "11.0";
  };
  hostInfo = plist "ctk-empty-host-info.plist" (
    common
    // {
      CFBundleIdentifier = hostID;
      CFBundleExecutable = "ctk-empty-host";
      CFBundleName = "Flakes Empty Token Probe";
      CFBundlePackageType = "APPL";
      LSUIElement = true;
    }
  );
  driverInfo = plist "ctk-empty-driver-info.plist" (
    common
    // {
      CFBundleIdentifier = driverID;
      CFBundleExecutable = "ctk-empty-driver";
      CFBundleName = "Flakes Empty Token Driver";
      CFBundlePackageType = "XPC!";
      NSExtension = {
        NSExtensionPointIdentifier = "com.apple.ctk-tokens";
        NSExtensionAttributes = {
          "com.apple.ctk.class-id" = driverID;
          "com.apple.ctk.driver-class" = "FlakesEmptyTokenDriver";
          "com.apple.ctk.token-type" = "persistent";
        };
      };
    }
  );
  entitlements = plist "ctk-empty-entitlements.plist" {
    "com.apple.security.app-sandbox" = true;
    "com.apple.security.smartcard" = true;
  };
in
pkgs.runCommand "flakes-ctk-empty-probe" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
  app="$out/FlakesEmptyTokenProbe.app"
  driver="$app/Contents/PlugIns/FlakesEmptyTokenDriver.appex"
  mkdir -p "$app/Contents/MacOS" "$driver/Contents/MacOS"
  cp ${hostInfo} "$app/Contents/Info.plist"
  cp ${driverInfo} "$driver/Contents/Info.plist"
  cc -Wall -Wextra -Werror -fobjc-arc ${./ctk-empty-host.m} \
    -framework Foundation -framework CryptoTokenKit -o "$app/Contents/MacOS/ctk-empty-host"
  cc -Wall -Wextra -Werror -fobjc-arc ${./ctk-empty-driver.m} \
    -framework Foundation -framework CryptoTokenKit -o "$driver/Contents/MacOS/ctk-empty-driver"
  /usr/bin/codesign --force --sign - --timestamp=none --identifier ${driverID} --entitlements ${entitlements} "$driver"
  /usr/bin/codesign --force --sign - --timestamp=none --identifier ${hostID} --entitlements ${entitlements} "$app"
  /usr/bin/codesign --verify --strict --deep "$app"
''
