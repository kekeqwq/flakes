# OpenSCToken PIN-Never driver: install + register for PIV lock-screen login.
# After darwin-rebuild, manually provision PIV keys and pair account (see README).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.opensctoken;
  driver = pkgs.callPackage ../../pkgs/opensctoken-pin-never { };
  appDir = "/Applications/Utilities/OpenSCTokenApp.app";
  extRel = "Contents/PlugIns/OpenSCToken.appex";
  installer = pkgs.writeShellScript "install-flakes-opensctoken" ''
            set -eu
            APP_SRC="${driver}/OpenSCToken.appex"
            APP_DST="${appDir}"
            USER_NAME=${lib.escapeShellArg config.system.primaryUser}
            EXT_ID=com.keke.flakes.opensctoken-app.OpenSCToken
            STAGE=$(/usr/bin/mktemp -d "$(/usr/bin/dirname "$APP_DST")/.opensctoken.XXXXXXXX")
            APP="$STAGE/OpenSCTokenApp.app"
            EXT="$APP/${extRel}"
            BACKUP="$STAGE/previous.app"
            installed=0
            cleanup() {
              status=$?
              if [ "$status" -ne 0 ]; then
                if [ "$installed" -eq 1 ]; then
                  /bin/mv "$APP_DST" "$STAGE/failed.app" || exit "$status"
                fi
                if [ -d "$BACKUP" ]; then
                  /bin/mv "$BACKUP" "$APP_DST" || exit "$status"
                fi
              fi
              /bin/rm -rf "$STAGE"
            }
            trap cleanup EXIT

            pluginkit_for_user() {
              local uid
              uid=$(/usr/bin/id -u "$USER_NAME") || return 1
              /bin/launchctl asuser "$uid" /usr/bin/sudo -n -u "$USER_NAME" -- \
                /usr/bin/pluginkit "$@"
            }
            registered() {
              local listing
              listing=$(pluginkit_for_user -m -A -v -i "$EXT_ID") || return 1
              /usr/bin/grep -Fq "$APP_DST/${extRel}" <<< "$listing"
            }
            register() {
              pluginkit_for_user -a "$APP_DST/${extRel}" || return 1
              registered
            }
            if [ -f "$APP_DST/Contents/Resources/driver-source" ] \
              && [ "$(/bin/cat "$APP_DST/Contents/Resources/driver-source")" = "$APP_SRC" ] \
              && /usr/bin/codesign --verify --deep --strict "$APP_DST"; then
              # An unchanged, already registered extension needs no write to
              # the registry. Do not invalidate a live token on each rebuild.
              registered || register
              exit 0
            fi

            /bin/mkdir -p "$APP/Contents/PlugIns" "$APP/Contents/MacOS" "$APP/Contents/Resources"
            /usr/bin/printf '%s\n' "$APP_SRC" > "$APP/Contents/Resources/driver-source"
            /usr/bin/printf '%s\n' 'int main(void) { return 0; }' \
              | /usr/bin/clang -x c - -o "$APP/Contents/MacOS/OpenSCTokenApp"
            /bin/cat > "$APP/Contents/Info.plist" << 'PLIST'
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
            /usr/bin/ditto "$APP_SRC" "$EXT"
            /bin/chmod -R u+w "$EXT"
            # Keep signing inputs outside the bundle: codesign interprets a plist
            # in this location as a nested component, not as a resource.
            /bin/mv "$EXT/Contents/entitlements.plist" "$STAGE/entitlements.plist"
            for dylib in "$EXT/Contents/Frameworks"/*.dylib; do
              [ -L "$dylib" ] || /usr/bin/codesign --force --sign - "$dylib"
            done
            /usr/bin/codesign --force --sign - --entitlements "$STAGE/entitlements.plist" "$EXT"
            /usr/bin/codesign --force --sign - "$APP"
            /usr/bin/codesign --verify --deep --strict "$APP"

            if [ -e "$APP_DST" ]; then /bin/mv "$APP_DST" "$BACKUP"; fi
            /bin/mv "$APP" "$APP_DST"
            installed=1
            register
            echo "OpenSCToken: verified and registered at $APP_DST"
  '';
in
{
  options.my.opensctoken = {
    enable = lib.mkEnableOption "OpenSCToken PIN-Never PIV driver";
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.extraActivation.text = lib.mkAfter ''
      if [ "''${checkActivation:-0}" != 1 ]; then
        ${installer} || exit 1
      fi
    '';
  };
}
