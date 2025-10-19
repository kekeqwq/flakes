{
  self,
  inputs,
  withSystem,
  ...
}:

let
  mkDarwin =
    {
      system ? "aarch64-darwin",
      modules ? [ ],
    }:
    withSystem system (
      { pkgs, system, ... }:
      inputs.darwin.lib.darwinSystem {
        inherit system;
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
        specialArgs = {
          inherit inputs;
        };
        modules = [
          inputs.home-manager.darwinModules.home-manager
        ]
        ++ modules;
      }
    );
in
{
  flake.darwinConfigurations = {
    mba = mkDarwin { modules = [ ../hosts/mba.nix ]; };
  };
}
