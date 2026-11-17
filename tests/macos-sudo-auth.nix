{ pkgs, darwin }:
let
  cfg = darwin.config.security.pam.services.sudo_local;
  shared = import ../System/Common/security-keys {
    inherit pkgs;
    inherit (pkgs) lib;
  };
  module = import ../macOS/private/pam-u2f.nix { inherit pkgs; };
  adapter = "${pkgs.pam-reattach}/lib/pam/pam_reattach.so";
  expected = pkgs.lib.concatLines [
    "auth       optional       ${adapter}"
    "auth       sufficient     ${module}/lib/security/pam_u2f.so authfile=${shared.mapping} origin=pam://keke-flakes appid=pam://keke-flakes userpresence=1 pinverification=0 userverification=0 cue"
    "auth       sufficient     pam_tid.so"
  ];
in
assert cfg.enable && cfg.touchIdAuth && cfg.reattach && !cfg.watchIdAuth;
assert cfg.text == expected;
assert builtins.length shared.registry.keys == 2;
assert builtins.elem (builtins.hashString "sha256" cfg.text)
  darwin.config.environment.etc."pam.d/sudo_local".knownSha256Hashes;
pkgs.runCommand "macos-sudo-key-touchid-policy" { sudoLocal = cfg.text; } ''
  test -r ${adapter}
  test -r ${module}/lib/security/pam_u2f.so
  test -r ${shared.mapping}
  grep -F /usr/lib/libpam.2.dylib ${module}/linkage.txt
  ! grep -E '/nix/store/.*(openpam|libpam)' ${module}/linkage.txt
  printf '%s' "$sudoLocal" > "$out"
  test "$(wc -l < "$out" | tr -d ' ')" = 3
  ! grep -Eq 'pam_permit|alwaysok|nouserok|nodetect|interactive|NOPASSWD' "$out"
''
