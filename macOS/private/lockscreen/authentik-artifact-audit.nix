# READ-ONLY development artifact audit. No system imports, installer, profile or service.
{ pkgs }:
assert pkgs.stdenv.hostPlatform.isDarwin;
let
  version = "0.73.0";
  package = pkgs.fetchurl {
    name = "authentik-${version}-candidate.pkg";
    url = "https://github.com/goauthentik/platform/releases/download/v${version}/authentik.Agent.Installer.pkg";
    hash = "sha256-N6rtRxg/ogvJA/E1jjOvT1t6hmvhm0vKzKRGYL+P/2c=";
  };
in
pkgs.runCommand "authentik-${version}-artifact-audit" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  mkdir -p "$out"
  python3 ${../../../tests/macos-authentik-artifact.test.py} ${package} ${../../../tests/macos-authentik-artifact.py}
  python3 ${../../../tests/macos-authentik-artifact.py} ${package} "$out/report.json"
''
