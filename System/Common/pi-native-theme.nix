{ pkgs, raw }:
let
  # Patch source before compilation: Pi runs a bundled CLI, not dist/theme.js.
  workspacePackages = raw.workspacePackages.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      ${pkgs.python3}/bin/python3 ${./pi-native-theme-patch.py} .
    '';
  });
  # The outer factory accepts buildNpmPackage, not the runtime's private args.
  # Reuse its original workspace derivation/toolchain with just our source fix.
  package = raw.override { buildNpmPackage = _: workspacePackages; };
in
package.overrideAttrs (old: {
  installCheckPhase = (old.installCheckPhase or "") + ''
    ${pkgs.nodejs}/bin/node ${./pi-native-theme.test.mjs} "$out/lib/node_modules/@earendil-works/pi-coding-agent"
  '';
})
