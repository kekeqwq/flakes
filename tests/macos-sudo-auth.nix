{ pkgs, darwin }:
let
  cfg = darwin.config.security.pam.services.sudo_local;
  module = "${pkgs.pam-reattach}/lib/pam/pam_reattach.so";
in
assert cfg.enable && cfg.touchIdAuth && cfg.reattach && !cfg.watchIdAuth;
assert cfg.text == "auth       optional       ${module}\nauth       sufficient     pam_tid.so\n";
assert builtins.elem (builtins.hashString "sha256" cfg.text)
  darwin.config.environment.etc."pam.d/sudo_local".knownSha256Hashes;
pkgs.runCommand "macos-sudo-touchid-policy" { sudoLocal = cfg.text; } ''
  test -r ${module}
  printf '%s' "$sudoLocal" > "$out"
  # Only an optional session adapter and sufficient biometric route. macOS's
  # existing sudo stack must retain the required OpenDirectory password route.
  test "$(wc -l < "$out" | tr -d ' ')" = 2
  ! grep -Eq 'pam_permit|alwaysok|NOPASSWD' "$out"
''
