{ inputs, ... }:
{
  flake.overlays.default = inputs.nixpkgs.lib.composeManyExtensions [
    (import ../pkgs)
    inputs.kikieye.overlays.default
    inputs.kikinavmap.overlays.default
    inputs.spotx-nix.overlays.default
  ];
}
