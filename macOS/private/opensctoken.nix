# OpenSCToken PIN-Never driver: install + register for PIV lock-screen login.
# After darwin-rebuild, manually provision PIV keys and pair account (see README).
{ config, lib, pkgs, ... }:
let
  cfg = config.my.opensctoken;
  driver = pkgs.callPackage ../../pkgs/opensctoken-pin-never { };
  appDir = "/Applications/Utilities/OpenSCTokenApp.app";
  extRel = "Contents/PlugIns/OpenSCToken.appex";
in
{
  options.my.opensctoken = {
    enable = lib.mkEnableOption "OpenSCToken PIN-Never PIV driver";
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.extraActivation.text = lib.mkAfter ''
      # Install OpenSCToken app bundle
      APP_SRC="${driver}/OpenSCToken.appex"
      APP_DST="${appDir}"
      if [ -d "$APP_SRC" ]; then
        mkdir -p "$APP_DST/Contents/PlugIns"
        # Create minimal containing app
        if [ ! -f "$APP_DST/Contents/MacOS/OpenSCTokenApp" ]; then
          mkdir -p "$APP_DST/Contents/MacOS"
          echo 'int main(){return 0;}' | clang -x c - -o "$APP_DST/Contents/MacOS/OpenSCTokenApp" 2>/dev/null || true
        fi
        cat > "$APP_DST/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.keke.flakes.opensctoken-app</string>
  <key>CFBundleExecutable</key><string>OpenSCTokenApp</string>
  <key>CFBundleName</key><string>OpenSCTokenApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
        rm -rf "$APP_DST/${extRel}"
        cp -R "$APP_SRC" "$APP_DST/${extRel}"

        # Ad-hoc sign (codesign not in Nix sandbox)
        ENT="$APP_DST/${extRel}/Contents/entitlements.plist"
        for lib in "$APP_DST/${extRel}/Contents/Frameworks"/*.dylib; do
          codesign --force --sign - "$lib" 2>/dev/null || true
        done
        codesign --force --sign - --entitlements "$ENT" "$APP_DST/${extRel}" 2>/dev/null || true
        codesign --force --sign - "$APP_DST" 2>/dev/null || true

        # Register extension
        pluginkit -a "$APP_DST/${extRel}" 2>/dev/null || true
        sudo -u _securityagent pluginkit -a "$APP_DST/${extRel}" 2>/dev/null || true

        echo "OpenSCToken: installed and registered at $APP_DST"
      fi
    '';
  };
}
