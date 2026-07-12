{ inputs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware.nix
    ./center.nix
  ];
}
