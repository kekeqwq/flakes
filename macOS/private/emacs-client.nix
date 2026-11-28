{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Only the client is used here, so this does not recursively depend on
  # finalPackage (whose Applications directory we replace below).
  editor = config.home-manager.users.${config.myuser.name}.programs.emacs.package;
  clientApp = pkgs.stdenv.mkDerivation {
    pname = "emacs-client-app";
    version = editor.version;
    src = ./emacs-client.m;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.python3 ];
    buildPhase = ''
      clang -fobjc-arc -framework Cocoa \
        -DEMACSCLIENT='"${editor}/bin/emacsclient"' \
        -x objective-c "$src" -o EmacsClient
    '';
    installPhase = ''
      mkdir -p "$out/Applications/Emacs.app/Contents/MacOS"
      cp -R ${editor}/Applications/Emacs.app/Contents/Resources \
        "$out/Applications/Emacs.app/Contents/Resources"
      cp EmacsClient "$out/Applications/Emacs.app/Contents/MacOS/EmacsClient"
      python3 - '${editor}/Applications/Emacs.app/Contents/Info.plist' \
        "$out/Applications/Emacs.app/Contents/Info.plist" <<'PY'
      import plistlib, sys
      with open(sys.argv[1], 'rb') as f:
          info = plistlib.load(f)
      info.update(CFBundleExecutable='EmacsClient',
                  CFBundleIdentifier='org.gnu.Emacs.Client',
                  CFBundleName='Emacs', CFBundleDisplayName='Emacs',
                  LSUIElement=True)
      info.pop('NSPrincipalClass', None)
      info.pop('NSMainNibFile', None)
      with open(sys.argv[2], 'wb') as f:
          plistlib.dump(info, f)
      PY
    '';
  };
in
{
  # Keep an untouched, package-aware native App as the daemon entry.
  # Changes to the client launcher must not change/restart the daemon service.
  myuser.hm.programs.emacs.overrides = _final: prev: {
    emacsWithPackages =
      packages:
      let
        original = prev.emacsWithPackages packages;
      in
      original.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          daemonPackage = original;
        };
        # emacsWithPackages uses buildCommand directly, not phase hooks.
        buildCommand = old.buildCommand + ''
          chmod -R u+w "$out/Applications"
          rm -rf "$out/Applications"
          mkdir -p "$out/Applications"
          ln -s ${clientApp}/Applications/Emacs.app "$out/Applications/Emacs.app"
          # Regression: a postBuild hook is not run by emacsWithPackages.
          # Ensure this is the client App, never the upstream standalone App.
          test -x "$out/Applications/Emacs.app/Contents/MacOS/EmacsClient"
          test ! -e "$out/Applications/Emacs.app/Contents/MacOS/Emacs"
        '';
      });
  };
  myuser.hm.services.emacs.package =
    config.home-manager.users.${config.myuser.name}.programs.emacs.finalPackage.daemonPackage;

  # User LaunchAgent: starts at login without a window and stays available.
  myuser.hm.launchd.agents.emacs.config = {
    ProgramArguments = lib.mkForce (
      [
        "${
          config.home-manager.users.${config.myuser.name}.services.emacs.package
        }/Applications/Emacs.app/Contents/MacOS/Emacs"
        "--fg-daemon"
      ]
      ++ config.home-manager.users.${config.myuser.name}.services.emacs.extraOptions
    );
    KeepAlive = lib.mkForce true;
    ProcessType = "Interactive";
    ThrottleInterval = 10;
    StandardOutPath = "${config.users.users.${config.myuser.name}.home}/Library/Logs/emacs-daemon.log";
    StandardErrorPath = "${
      config.users.users.${config.myuser.name}.home
    }/Library/Logs/emacs-daemon.log";
  };
}
