{ inputs, ... }: {
  imports = [
    ./configuration.nix
    ./hardware.nix
    ./wayland.nix
    "${inputs.jovian}/modules"
  ];
}
