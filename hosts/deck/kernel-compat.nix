{ lib, pkgs, ... }:
let
  # Current Jovian moved to 7.3, outside stable ZFS 2.4.4's supported kernels.
  # Deck boots from ZFS: retain its last validated vendor kernel rather than
  # allowing a broken module, switching to generic Linux or importing a pool
  # with experimental ZFS. The rest of Jovian still follows flake.lock.
  compatibleJovian = builtins.fetchTree {
    type = "github";
    owner = "Jovian-Experiments";
    repo = "Jovian-NixOS";
    rev = "fdffe0d20fbadeb4958e16c4e4c41108aff92223";
    narHash = "sha256-egiRyZq+yEvpF0z5m038SngrDA3hCXlhBB4CoSvrZ6Y=";
  };
  kernel = pkgs.callPackage "${compatibleJovian.outPath}/pkgs/linux" {
    kernelPatches = [
      pkgs.kernelPatches.bridge_stp_helper
      pkgs.kernelPatches.request_key_helper
    ];
  };
in
{
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);
}
