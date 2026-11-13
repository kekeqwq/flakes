{ lib, pkgs, ... }:
{
  # Starting point for every new Linux desktop instance. Hosts add only their
  # own identity, storage, displays and host-private services.
  my.desktop.enable = true;

  # Follow the newest stable kernel; per-host hardware still gets validation.
  # Deck keeps Jovian's kernel instead of importing this file.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Accounts stay editable at runtime: the initial password is set during
  # installation with `passwd --root`, never stored here.
  users.mutableUsers = lib.mkDefault true;
}
