# Experimental empty/non-login refusal probes. Never part of system activation.
{
  pkgs,
  probeKind ? "empty",
}:
assert builtins.elem probeKind [
  "empty"
  "denial"
];
let
  denial = probeKind == "denial";
  hostID = "com.keke.flakes.ctk-${probeKind}-probe";
  driverID = "${hostID}.driver";
  appName = if denial then "FlakesDenialTokenProbe" else "FlakesEmptyTokenProbe";
  driverName = if denial then "FlakesDenialTokenDriver" else "FlakesEmptyTokenDriver";
  hostBin = "ctk-${probeKind}-host";
  driverBin = "ctk-${probeKind}-driver";
  hostSource = if denial then ./ctk-denial-host.m else ./ctk-empty-host.m;
  driverSource = if denial then ./ctk-denial-driver.m else ./ctk-empty-driver.m;
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
      CFBundleExecutable = hostBin;
      CFBundleName = appName;
      CFBundlePackageType = "APPL";
      LSUIElement = true;
    }
  );
  driverInfo = plist "ctk-empty-driver-info.plist" (
    common
    // {
      CFBundleIdentifier = driverID;
      CFBundleExecutable = driverBin;
      CFBundleName = driverName;
      CFBundlePackageType = "XPC!";
      NSExtension = {
        NSExtensionPointIdentifier = "com.apple.ctk-tokens";
        NSExtensionAttributes = {
          "com.apple.ctk.class-id" = driverID;
          "com.apple.ctk.driver-class" = driverName;
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
pkgs.runCommand "flakes-ctk-${probeKind}-probe" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
  app="$out/${appName}.app"
  driver="$app/Contents/PlugIns/${driverName}.appex"
  mkdir -p "$app/Contents/MacOS" "$driver/Contents/MacOS"
  cp ${hostInfo} "$app/Contents/Info.plist"
  cp ${driverInfo} "$driver/Contents/Info.plist"
  cc -Wall -Wextra -Werror -fobjc-arc -I${./.} ${hostSource} \
    -framework Foundation -framework CryptoTokenKit -framework Security -framework LocalAuthentication \
    -o "$app/Contents/MacOS/${hostBin}"
  cc -Wall -Wextra -Werror -fobjc-arc -I${./.} ${driverSource} \
    -framework Foundation -framework CryptoTokenKit -framework Security \
    -o "$driver/Contents/MacOS/${driverBin}"
  /usr/bin/codesign --force --sign - --timestamp=none --identifier ${driverID} --entitlements ${entitlements} "$driver"
  /usr/bin/codesign --force --sign - --timestamp=none --identifier ${hostID} --entitlements ${entitlements} "$app"
  /usr/bin/codesign --verify --strict --deep "$app"
''
