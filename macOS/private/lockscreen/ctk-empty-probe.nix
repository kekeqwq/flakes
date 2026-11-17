# Experimental empty/non-login refusal probes. Never part of system activation.
{
  pkgs,
  probeKind ? "empty",
}:
assert builtins.elem probeKind [
  "empty"
  "denial"
  "fido"
];
let
  fido = probeKind == "fido";
  denial = probeKind != "empty";
  shared = import ../../../System/Common/security-keys {
    inherit pkgs;
    lib = pkgs.lib;
  };
  nativePam = import ../pam-u2f.nix { inherit pkgs; };
  hostID = "com.keke.flakes.ctk-${probeKind}-probe";
  driverID = "${hostID}.driver";
  appName =
    if fido then
      "FlakesFidoTokenProbe"
    else if denial then
      "FlakesDenialTokenProbe"
    else
      "FlakesEmptyTokenProbe";
  driverName =
    if fido then
      "FlakesFidoTokenDriver"
    else if denial then
      "FlakesDenialTokenDriver"
    else
      "FlakesEmptyTokenDriver";
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
  baseEntitlements = {
    "com.apple.security.app-sandbox" = true;
    "com.apple.security.smartcard" = true;
  };
  entitlements = plist "ctk-probe-entitlements.plist" baseEntitlements;
  driverEntitlements = plist "ctk-driver-entitlements.plist" (
    baseEntitlements
    // pkgs.lib.optionalAttrs fido {
      "com.apple.security.device.usb" = true;
    }
  );
  workerEntitlements = plist "ctk-worker-entitlements.plist" {
    "com.apple.security.app-sandbox" = true;
    "com.apple.security.inherit" = true;
  };
  flags = pkgs.lib.optionalString fido "-DFLAKES_FIDO_PROBE";
in
assert !fido || pkgs.lib.all (a: a.assertion) shared.assertions;
pkgs.runCommand "flakes-ctk-${probeKind}-probe"
  {
    nativeBuildInputs = [
      pkgs.stdenv.cc
      pkgs.python3
      pkgs.darwin.cctools
    ];
  }
  ''
    app="$out/${appName}.app"
    driver="$app/Contents/PlugIns/${driverName}.appex"
    mkdir -p "$app/Contents/MacOS" "$driver/Contents/MacOS"
    cp ${hostInfo} "$app/Contents/Info.plist"
    cp ${driverInfo} "$driver/Contents/Info.plist"
    cc -Wall -Wextra -Werror -fobjc-arc ${flags} -I${./.} ${hostSource} \
      -framework Foundation -framework CryptoTokenKit -framework Security -framework LocalAuthentication -framework CoreGraphics -framework IOKit \
      -o "$app/Contents/MacOS/${hostBin}"
    cc -Wall -Wextra -Werror -fobjc-arc ${flags} -I${./.} ${driverSource} \
      -framework Foundation -framework CryptoTokenKit -framework Security -framework CoreGraphics -framework IOKit \
      -o "$driver/Contents/MacOS/${driverBin}"
    ${pkgs.lib.optionalString fido ''
      cc -Wall -Wextra -Werror -fobjc-arc -I${./.} ${../../../tests/macos-lock-gate.m} \
        -framework Foundation -framework CoreGraphics -framework IOKit -o lock-gate-test
      ./lock-gate-test
      mkdir -p "$driver/Contents/Resources"
      cp ${shared.mapping} "$driver/Contents/Resources/public-u2f-keys"
      python3 ${./bundle-pam.py} ${nativePam}/lib/security/pam_u2f.so "$driver/Contents/Frameworks"
      cc -Wall -Wextra -Werror -fobjc-arc -I${./.} -I${pkgs.pam}/include ${./ctk-fido-worker.m} \
        -framework Foundation -framework CoreGraphics -framework IOKit -o "$driver/Contents/MacOS/ctk-fido-worker"
      /usr/bin/codesign --force --sign - --timestamp=none --entitlements ${workerEntitlements} "$driver/Contents/MacOS/ctk-fido-worker"
    ''}
    /usr/bin/codesign --force --sign - --timestamp=none --identifier ${driverID} --entitlements ${driverEntitlements} "$driver"
    /usr/bin/codesign --force --sign - --timestamp=none --identifier ${hostID} --entitlements ${entitlements} "$app"
    /usr/bin/codesign --verify --strict --deep "$app"
    ${pkgs.lib.optionalString fido ''
      mkdir -p "$out/bin"
      printf '%s\n' '#!${pkgs.runtimeShell}' 'set -euo pipefail' \
        'if [ "$#" -ne 0 ]; then echo "Use a local terminal, no arguments, no sudo." >&2; exit 2; fi' \
        "exec ${pkgs.python3}/bin/python3 ${../../../tests/macos-ctk-probe.py} \"$app\" --kind fido --lock-touch" \
        > "$out/bin/flakes-test-locked-key"
      chmod 755 "$out/bin/flakes-test-locked-key"
    ''}
  ''
