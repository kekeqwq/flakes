{ config, ... }:
{
  # macOS includes sudo_local before its standard password authentication.
  # pam_tid is sufficient, not required: password fallback stays available.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    # Rejoin the GUI bootstrap session for Ghostty/tmux/screen clients.
    reattach = true;
  };
  # Permit a narrow deployment of this exact generated file before a later
  # full Darwin switch. nix-darwin will recognize it and restore its canonical
  # /etc/static link instead of treating it as an unmanaged PAM replacement.
  environment.etc."pam.d/sudo_local".knownSha256Hashes = [
    (builtins.hashString "sha256" config.security.pam.services.sudo_local.text)
    # Exact narrowly deployed pam_reattach-1.3 + pam_tid file. Keep recognition
    # if a later package update changes the generated library's store path.
    "373b30ffaef8492e8f6b4566f388c910e1e209270b9732ae999d1963e92abc7b"
  ];
}
