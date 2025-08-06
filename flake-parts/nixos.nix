{
  self,
  inputs,
  withSystem,
  ...
}:

let
  mkNixos =
    {
      system ? "x86_64-linux",
      modules ? [ ],
      desktop ? true,
    }:
    withSystem system (
      { pkgs, system, ... }:
      inputs.nixpkgs.lib.nixosSystem {
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
          inputs.home-manager.nixosModules.home-manager
          ../common
          ../nixos/pkgs.nix
        ]
        ++ pkgs.lib.optionals desktop [ ../nixos/desktop ]
        ++ modules;
      }
    );
in
{
  flake.nixosConfigurations = {
    pc = mkNixos { modules = [ ../hosts/pc ]; };
    deck = mkNixos {
      modules = [
        ../hosts/deck
        inputs.jovian.nixosModules.default
      ];
    };
  };
}
