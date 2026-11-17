{ pkgs }:
let
  module = import ../macOS/private/pam-u2f.nix { inherit pkgs; };
  shared = import ../System/Common/security-keys {
    inherit pkgs;
    inherit (pkgs) lib;
  };
in
pkgs.writeShellScriptBin "flakes-probe-u2f-root" ''
  set -euo pipefail
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  test "$(id -u)" = 0
  test "''${SUDO_USER:-}" = keke
  install -d -o root -g wheel -m 700 /var/root/flakes-sudo-key-probes
  report=$(mktemp /var/root/flakes-sudo-key-probes/probe.XXXXXX)
  echo 'Root module probe starting. Existing sudo approval is not Key acceptance.'
  echo 'Now touch only the Key when its LED requests presence. No password/PIN.'
  exec ${pkgs.python3}/bin/python3 ${./macos-u2f-module.py} \
    --module ${module}/lib/security/pam_u2f.so \
    --mapping ${shared.mapping} --label secondary --root-probe \
    --timeout 30 --report "$report"
''
