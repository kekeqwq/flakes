{ inputs, ... }:
{
  imports = [
    inputs.jovian.nixosModules.default
    ./configuration.nix
    ./hardware.nix
    ./kernel-compat.nix
    ./center.nix
    ./openlist.nix
    ./shell.nix
  ];
}
