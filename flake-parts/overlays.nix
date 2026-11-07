{ inputs, ... }:
{
  flake.overlays.default = inputs.nixpkgs.lib.composeManyExtensions [
    (import ../pkgs)
    inputs.kikieye.overlays.default
  ];
}
