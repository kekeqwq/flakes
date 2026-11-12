{
  lib,
  pkgs,
  ...
}:
let
  x86Linux = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  programs.weylus = {
    enable = true;
    users = [ "keke" ];
  };

  # VIA ships an x86_64-only binary.
  services.udev.packages = lib.optionals x86Linux [ pkgs.via ];

  environment.systemPackages =
    with pkgs;
    [
      localsend
      prismlauncher
      telegram-desktop
      (google-chrome.override {
        commandLineArgs = "--password-store=basic";
      })
    ]
    # Discord has no aarch64-linux build.
    ++ lib.optionals x86Linux [ discord ];
}
