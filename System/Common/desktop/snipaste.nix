{ lib, pkgs, ... }:
{
  # Same desktop application; macOS uses its native Homebrew cask in the
  # private installer layer, just like Ghostty. Upstream Linux is x86_64-only.
  myuser.hm.home.packages = lib.optionals (
    pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64
  ) [ pkgs.snipaste ];
}
