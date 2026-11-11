{ inputs, ... }:
{
  imports = [
    inputs.jovian.nixosModules.default
    ./configuration.nix
    ./hardware.nix
    ./center.nix
    ./openlist.nix
    ./shell.nix
  ];
}
