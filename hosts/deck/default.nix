{ inputs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware.nix
    "${inputs.jovian}/modules"
  ];
}
