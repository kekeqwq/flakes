{
  config,
  lib,
  pkgs,
  ...
}:
let
  shared = import ../../System/Common/security-keys { inherit lib pkgs; };
  module = import ./pam-u2f.nix { inherit pkgs; };
  registry = shared.registry;
in
{
  assertions = shared.assertions;
  # macOS includes sudo_local before its standard password authentication.
  # Native modules are sufficient alternatives, never password requirements.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    # Rejoin the GUI bootstrap session for Ghostty/tmux/screen clients.
    reattach = true;
    # Override the generated ordering, retaining the declared adapters above.
    # No nodetect/interactive: absent or unsuitable keys fall through promptly.
    text = lib.mkForce (
      lib.concatLines [
        "auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so"
        "auth       sufficient     ${module}/lib/security/pam_u2f.so authfile=${shared.mapping} origin=${registry.origin} appid=${registry.origin} userpresence=1 pinverification=0 userverification=0 cue"
        "auth       sufficient     pam_tid.so"
      ]
    );
  };
  # Permit a narrow deployment of this exact generated file before a later
  # full Darwin switch. nix-darwin will recognize it and restore its canonical
  # /etc/static link instead of treating it as an unmanaged PAM replacement.
  environment.etc."pam.d/sudo_local".knownSha256Hashes = [
    (builtins.hashString "sha256" config.security.pam.services.sudo_local.text)
    # Preserve recognition of the previous generated Touch-ID-only file too.
    (builtins.hashString "sha256" (
      lib.concatLines [
        "auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so"
        "auth       sufficient     pam_tid.so"
      ]
    ))
    # Exact narrowly deployed pam_reattach-1.3 + pam_tid file. Keep recognition
    # if a later package update changes the generated library's store path.
    "373b30ffaef8492e8f6b4566f388c910e1e209270b9732ae999d1963e92abc7b"
  ];
}
